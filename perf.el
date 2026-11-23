;;; perf.el --- Performance budgets for the hot paths  -*- lexical-binding: t; -*-

;;; Commentary:

;; The numbers this package's design rests on, as budgets rather than prose.
;; `make perf-check' measures them and fails when one goes over; `make perf'
;; prints the same table and never fails, for a machine that is not quiet.
;;
;; Two kinds of budget live here.  Absolute ones are generous multiples of the
;; baselines in docs/architecture.md, wide enough to survive a loaded machine.
;; Relative ones compare two measurements taken in the same run, because a
;; ratio survives a slow machine where a millisecond does not.
;;
;; The benchmarks measure Emacs, not this package: what a buffer insert costs,
;; what a forced redisplay costs, how promptly a process filter is called, what
;; a JSON event costs to parse.  They are the substrate the design is budgeted
;; against, so they are worth guarding before there is code to guard.

;;; Code:

(require 'cl-lib)
(require 'json)

(defconst p/perf-runs 3
  "Runs per benchmark.  The median is taken, so one noisy run cannot fail a
build on its own.")

(defconst p/perf-chunks 300
  "Chunks inserted by the streaming benchmarks.  Small enough to keep the
suite under a few seconds, large enough that per-chunk cost is not dominated
by setup.")

(defvar p/perf-registry nil
  "Benchmarks, oldest first.  Each entry is a plist with :name, :doc,
:budget, :needs-tty and :fn.")

(defun p/perf-tty-p ()
  "Return non-nil when redisplay actually paints something.
Set by `ci/run-perf.sh' when it could run Emacs under a terminal."
  (equal (getenv "PERF_TTY") "1"))

(defmacro p/defperf (name &rest args)
  "Define a benchmark NAME.
ARGS is an optional :tty keyword, a docstring, then the body.  The body must
return a number to be measured, or nil to skip.  The budget is not here: it
lives in the policy file with every other number."
  (declare (indent 2))
  (let ((plist nil) (doc nil) (body nil))
    (while (keywordp (car args))
      (setq plist (append plist (list (pop args) (pop args)))))
    (setq doc (pop args) body args)
    `(setq p/perf-registry
           (append p/perf-registry
                   (list (list :name ',name :doc ,doc
                               :needs-tty ,(plist-get plist :tty)
                               :fn (lambda () ,@body)))))))

(defun p/perf-median (values)
  "Return the median of VALUES, a list of numbers, or nil when it is empty.
A benchmark that returns nil on every run is a skip, and a skip has no
median; taking one anyway signalled an error and lost the whole table."
  (when values
    (let* ((sorted (sort (copy-sequence values) #'<))
           (n (length sorted)))
      (if (cl-evenp n)
          (/ (+ (nth (1- (/ n 2)) sorted) (nth (/ n 2) sorted)) 2.0)
        (float (nth (/ n 2) sorted))))))

(defun p/perf-chunk (i)
  "Return the stream chunk numbered I."
  (format "token%03d the loop and the session and the patch. " i))

(defun p/perf-fill (lines)
  "Insert LINES lines of already-read conversation into the current buffer."
  (dotimes (i lines)
    (insert (format "- old round %d: 3 files changed, 2 tests passed\n" i))))

(defun p/perf-setup (lines)
  "Return a console-like buffer holding LINES lines of history."
  (let ((buffer (get-buffer-create " *perf-console*")))
    (with-current-buffer buffer
      (erase-buffer)
      (text-mode)
      (font-lock-mode 1)
      (p/perf-fill lines))
    buffer))

;;; Benchmarks

(p/defperf insert-per-chunk
  "Insert one stream chunk without redisplay, in ms."
  (p/perf-insert-cost 2000))

(defun p/perf-insert-cost (lines)
  "Return the per-chunk insert cost, in ms, in a buffer of LINES lines."
  (with-current-buffer (p/perf-setup lines)
    (let ((start (float-time)))
      (dotimes (i p/perf-chunks)
        (goto-char (point-max))
        (insert (p/perf-chunk i)))
      (/ (* 1000 (- (float-time) start)) (float p/perf-chunks)))))

(p/defperf insert-size-ratio
  "Insert cost in a long buffer over the cost in an empty one."
  (let ((small (p/perf-insert-cost 0))
        (large (p/perf-insert-cost 20000)))
    (if (zerop small) 999.0 (/ large small))))

(p/defperf redisplay-per-chunk :tty t
  "Insert one chunk and force a redisplay, in ms."
  (with-current-buffer (p/perf-setup 2000)
    (switch-to-buffer (current-buffer))
    (let ((start (float-time)))
      (dotimes (i p/perf-chunks)
        (goto-char (point-max))
        (insert (p/perf-chunk i))
        (redisplay t))
      (/ (* 1000 (- (float-time) start)) p/perf-chunks))))

(p/defperf batch-ratio :tty t
  "How many times cheaper a redisplay every 20 chunks is, as a ratio."
  (let (each batched)
    (with-current-buffer (p/perf-setup 0)
      (switch-to-buffer (current-buffer))
      (let ((start (float-time)))
        (dotimes (i p/perf-chunks)
          (goto-char (point-max))
          (insert (p/perf-chunk i))
          (redisplay t))
        (setq each (- (float-time) start))))
    (with-current-buffer (p/perf-setup 0)
      (switch-to-buffer (current-buffer))
      (let ((start (float-time)))
        (dotimes (i p/perf-chunks)
          (goto-char (point-max))
          (insert (p/perf-chunk i))
          (when (zerop (% (1+ i) 20))
            (redisplay t)))
        (setq batched (- (float-time) start))))
    (if (zerop batched) 999.0 (/ each batched))))

(defun p/perf-filter-facts ()
  "Return (EVENTS-PER-CALL . GAP-SPREAD) for a 20 ms producer.
Events per filter call says whether the process layer coalesces deliveries;
the spread of the gaps says whether a delivery was ever stalled.  Both are
independent of the producer's exact period, which is why they are measured
instead of the gap itself."
  (let* ((start (float-time))
         (arrivals nil)
         (calls 0)
         (events 0)
         (proc (make-process
                :name "perf-consumer"
                :command (list "sh" "-c"
                               (concat "i=0; while [ $i -lt 40 ]; do "
                                       "echo 'data: x'; echo; "
                                       "i=$((i+1)); sleep 0.02; done"))
                :connection-type 'pipe
                :coding 'utf-8-unix
                :noquery t
                :filter (lambda (_p chunk)
                          (setq calls (1+ calls))
                          (dolist (line (split-string chunk "\n" t))
                            (when (string-prefix-p "data:" line)
                              (setq events (1+ events))
                              (push (- (float-time) start) arrivals)))))))
    (while (process-live-p proc)
      (accept-process-output proc 0.05))
    (accept-process-output nil 0.05)
    (let ((sorted (sort arrivals #'<))
          (gaps nil))
      (while (cdr sorted)
        (push (* 1000 (- (cadr sorted) (car sorted))) gaps)
        (setq sorted (cdr sorted)))
      (cons (if (zerop calls) 0.0 (/ (float events) calls))
            (if gaps (- (cl-reduce #'max gaps) (cl-reduce #'min gaps)) 0.0)))))

(p/defperf filter-events-per-call
  "Events delivered per process-filter call.  Above one means coalescing."
  (car (p/perf-filter-facts)))

(p/defperf filter-gap-spread
  "Difference between the widest and narrowest delivery gap, in ms."
  (cdr (p/perf-filter-facts)))

(p/defperf json-per-event
  "Parse one streamed event object, in ms."
  (let* ((events (cl-loop for i below 300
                          collect (format "{\"i\":%d,\"s\":\"text\"}" i)))
         (start (float-time)))
    (dolist (event events)
      (with-temp-buffer
        (insert event)
        (goto-char (point-min))
        (json-parse-buffer :object-type 'plist)))
    (/ (* 1000 (- (float-time) start)) (float (length events)))))

;;; Runner

(defun p/perf-budget (name)
  "Return the budget plist registered for benchmark NAME."
  (cdr (assq name (p/config-value :perf))))

(defun p/perf-expectation (entry)
  "Return the budget plist for ENTRY, read from the policy file."
  (p/perf-budget (plist-get entry :name)))

(defun p/perf-verdict (value budget)
  "Return `ok', `warn' or `skip' for VALUE against BUDGET."
  (cond
   ((numberp (plist-get budget :max))
    (if (<= value (plist-get budget :max)) 'ok 'over))
   ((numberp (plist-get budget :min))
    (if (>= value (plist-get budget :min)) 'ok 'under))
   (t 'unbudgeted)))

(defun p/perf-measure (entry)
  "Return the median measurement for ENTRY, or nil when it does not apply."
  (let ((fn (plist-get entry :fn)))
    (when (or (not (plist-get entry :needs-tty)) (p/perf-tty-p))
      (p/perf-median
       (cl-loop repeat p/perf-runs
                for value = (funcall fn)
                when (numberp value) collect value)))))

(defvar p/perf-name-width 20
  "Width of the benchmark column, set from the longest name in the registry.
Twenty is the floor, because a narrow table with a two-word heading reads
better than a ragged one; a package with names longer than that gets the
column it needs instead of a table whose columns drift to the right.")

(defun p/perf-row (name median budget stat doc)
  "Return one report row: NAME, MEDIAN, BUDGET, STAT and DOC."
  (format (concat "%-" (number-to-string p/perf-name-width)
                  "s %9s %11s  %-10s  %s")
          name median budget stat doc))

(defun p/perf-line (entry value budget verdict)
  "Return the report line for ENTRY with VALUE, BUDGET and VERDICT."
  (p/perf-row (symbol-name (plist-get entry :name))
              (if value (format "%.4f" value) "-")
              (cond ((numberp (plist-get budget :max))
                     (format "max %.2f" (plist-get budget :max)))
                    ((numberp (plist-get budget :min))
                     (format "min %.2f" (plist-get budget :min)))
                    (t "-"))
              (pcase verdict ('ok "ok") ('over "OVER") ('under "UNDER")
                     ('skip "skip") ('unbudgeted "no budget")
                     (_ "?"))
              (plist-get entry :doc)))

(defun p/perf-load-project ()
  "Load the project's own benchmarks, when it has any.
The benchmarks above measure Emacs rather than this package, so they are
shared. A package's own hot path is measured in `config/perf.el', which is
loaded here and can register more with `p/defperf'. Budgets stay in
`config/ci.el', next to every other policy number."
  (let* ((here (file-name-directory (or load-file-name buffer-file-name)))
         (project (expand-file-name "../config/perf.el" here)))
    (when (file-exists-p project)
      (load project nil t))))

(p/perf-load-project)

(defun p/perf-main (args)
  "Run every benchmark in ARGS and report.  Return the exit status.
`--report' prints the same table but never fails.  The table goes to the file
named by PERF_OUT; the status, to PERF_STATUS, so a wrapper such as `script'
cannot lose it."
  (let ((report-only (member "--report" args))
        (failures 0)
        (out (or (getenv "PERF_OUT") nil))
        (table nil))
    (setq p/perf-name-width
          (cl-loop for entry in p/perf-registry
                   maximize (length (symbol-name (plist-get entry :name)))
                   into width
                   finally return (max 20 width)))
    (push (p/perf-row "benchmark" "median" "budget" "stat"
                      "what it measures")
          table)
    (dolist (entry p/perf-registry)
      (let* ((value (p/perf-measure entry))
             (budget (p/perf-expectation entry))
             (verdict (if (numberp value) (p/perf-verdict value budget) 'skip)))
        (when (memq verdict '(over under)) (setq failures (1+ failures)))
        (push (p/perf-line entry value budget verdict) table)))
    (setq table (concat (mapconcat #'identity (nreverse table) "\n") "\n"))
    (if out
        (with-temp-file out (insert table))
      (princ table))
    (let ((status (if (and (> failures 0) (not report-only)) 1 0))
          (status-file (getenv "PERF_STATUS")))
      (when status-file
        (with-temp-file status-file (insert (format "%d" status))))
      status)))

(defun p/perf-main-or-die (args)
  "Run `p/perf-main' on ARGS and exit Emacs with the status it returns.
This is what `ci/run-perf.sh' evaluates, in batch and under a terminal alike,
and the difference between the two is the point.  Batch mode turns a signalled
error into a non-zero exit by itself; a tty Emacs catches it, prints it in the
echo area and returns to its command loop, which `script' is content to keep
alive until the timeout kills it.  Five silent minutes for a typo is a worse
report than the typo, so the error is written to stderr and Emacs exits."
  (condition-case err
      (kill-emacs (p/perf-main args))
    (error
     (princ (format "perf: %s\n" (error-message-string err))
            'external-debugging-output)
     (kill-emacs 1))))

(provide 'perf)

;;; perf.el ends here
