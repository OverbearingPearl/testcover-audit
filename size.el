;;; size.el --- What a module costs and repeats  -*- lexical-binding: t; -*-

;;; Commentary:

;; A run can take a unit whose proof is a number rather than a story: two
;; modules that spell the same five lines twice collapse into one call,
;; nothing a user can observe changes, and the proof is the call sites that
;; go, N to one.
;;
;; This file is where that number comes from.  It counts the lines of every
;; module and finds the runs of significant lines that appear twice.  It is a
;; report and never a check: `make size' prints and exits zero, because size
;; is not a fault -- a console is the largest module because presentation is
;; the widest thing in it -- and a number that fails a build is a number
;; somebody pads around.  The question it answers is the one a candidate list
;; asks: is this duplication, and can it be named?
;;
;; Where it looks is policy and lives in the `:size' table of `ci/config.el':
;; which directories hold modules, how many lines make a run worth reporting,
;; the length at which a module is named, and what counts as a line not worth
;; comparing in this language.  A package that can count something else --
;; definitions, promises, endpoints -- sets `p/size-definitions' in
;; `config/size.el', which is loaded here when it exists, and the report grows
;; a column; without it, lines and runs are the whole table.
;;
;; What it cannot see, said plainly because the report is read as fact: the
;; match is on text.  A run of lines that is one idea with different names is
;; invisible, and folding three functions into one can make either number say
;; anything.  An empty report means nobody copy-pasted, not that nothing is
;; duplicated.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst p/size-shortest 8
  "Lines no longer than this are not compared.
`(when x' and `(t))' close a form two modules share without sharing a
thought, and the shortest line worth calling a body is longer than they are.")

(defvar p/size-definitions nil
  "Function counting the definitions of one file, or nil.
Set in `config/size.el' by a package that has a definition count of its
own, and asked once per module.  The report prints the column only when
this is set, because a column of zeroes would say the package defines
nothing rather than that nothing was counted.")

(defun p/size-option (key)
  "Return the `:size' policy value for KEY."
  (plist-get (p/config-value :size) key))

(defun p/size-significant (line)
  "Return LINE trimmed when it is worth comparing, nil otherwise.
A blank line, a comment and an import are lines two modules share without
sharing anything: every file has them, and none of them is the duplicated
body this report is for.  Which prefixes mark those is `:skip' in the
policy, because that is the one part of this that depends on the language."
  (let ((text (string-trim line)))
    (and (> (length text) p/size-shortest)
         (not (seq-some (lambda (rx) (string-match-p rx text))
                        (p/size-option :skip)))
         text)))

(defun p/size-lines (file)
  "Return a vector of (LINE-NUMBER . TEXT) for FILE's significant lines."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((found '()))
      (while (not (eobp))
        (let ((text (p/size-significant
                     (buffer-substring-no-properties
                      (line-beginning-position) (line-end-position)))))
          (when text
            (push (cons (line-number-at-pos) text) found)))
        (forward-line 1))
      (vconcat (nreverse found)))))

(defun p/size-windows (lines window)
  "Return a hash of WINDOW text to the indexes in LINES it starts at."
  (let ((table (make-hash-table :test #'equal))
        (last (- (length lines) (1- window))))
    (dotimes (start (max 0 last))
      (let ((key (mapconcat (lambda (at) (cdr (aref lines at)))
                            (number-sequence start (+ start (1- window)))
                            "\n")))
        (push start (gethash key table))))
    table))

(defun p/size-index (modules)
  "Return two hashes: the lines of each module, and the windows in them.
MODULES is an alist of module name to absolute path; a window is located by
the module name and the index into that module's significant lines."
  (let ((lines (make-hash-table :test #'equal))
        (windows (make-hash-table :test #'equal))
        (window (p/size-option :window)))
    (dolist (module modules)
      (let ((text (p/size-lines (cdr module))))
        (puthash (car module) text lines)
        (maphash (lambda (key starts)
                   (dolist (start starts)
                     (push (cons (car module) start)
                           (gethash key windows))))
                 (p/size-windows text window))))
    (cons lines windows)))

(defun p/size-extend (lines window first second)
  "Return how many lines match, starting at FIRST and SECOND in LINES.
A matched run is extended as far as it goes, so a copy-pasted block is
reported once at its full length rather than once per WINDOW in it."
  (let* ((one (gethash (car first) lines))
         (two (gethash (car second) lines))
         (length window)
         (at (cdr first))
         (other (cdr second)))
    (while (and (< (+ at length) (length one))
                (< (+ other length) (length two))
                (equal (cdr (aref one (+ at length)))
                       (cdr (aref two (+ other length)))))
      (setq length (1+ length)))
    length))

(defun p/size-pairs (windows)
  "Return every pair of adjacent positions that share a window."
  (let ((pairs '()))
    (maphash (lambda (_key positions)
               (let ((sorted (sort positions
                                   (lambda (a b)
                                     (if (equal (car a) (car b))
                                         (< (cdr a) (cdr b))
                                       (string< (car a) (car b)))))))
                 (while (cdr sorted)
                   (push (cons (car sorted) (cadr sorted)) pairs)
                   (setq sorted (cdr sorted)))))
             windows)
    pairs))

(defun p/size-runs (lines windows)
  "Return (MODULE LINE MODULE LINE LENGTH TEXT) for the repeats found."
  (let ((window (p/size-option :window))
        (runs '()))
    (dolist (pair (p/size-pairs windows))
      (let* ((first (car pair))
             (second (cdr pair))
             (one (aref (gethash (car first) lines) (cdr first)))
             (two (aref (gethash (car second) lines) (cdr second))))
        (push (list (car first) (car one)
                    (car second) (car two)
                    (p/size-extend lines window first second)
                    (cdr one))
              runs)))
    runs))

(defun p/size-covered-p (run kept)
  "Return non-nil when one end of RUN lies inside a run already KEPT."
  (cl-some (lambda (other)
             (cl-some (lambda (at)
                        (and (equal (car at) (car other))
                             (<= (nth 1 other) (cdr at)
                                 (+ (nth 1 other) (1- (nth 4 other))))))
                      (list (cons (nth 0 run) (nth 1 run))
                            (cons (nth 2 run) (nth 3 run)))))
           kept))

(defun p/size-longest (runs)
  "Return RUNS without the ones that a longer run already covers."
  (let ((kept '()))
    (dolist (run (sort runs (lambda (a b) (> (nth 4 a) (nth 4 b)))))
      (unless (p/size-covered-p run kept)
        (push run kept)))
    (nreverse kept)))

(defun p/size-name (file)
  "Return FILE's base name, which is how the report names a module.
The directory is dropped because a run is read as `module:line', and the
file name says which module: two modules of the same name in two
directories are one module to a reader anyway."
  (file-name-nondirectory file))

(defun p/size-brief (name)
  "Return NAME without its package prefix and extension.
The prefix is what this repository's main file is called, and it is asked
for rather than assumed: a package whose modules do not carry it keeps the
base name, which is what the report should say."
  (let* ((bare (file-name-sans-extension name))
         (package (condition-case nil (p/package-name) (error nil)))
         (prefix (and package (concat package "-"))))
    (if (and prefix (string-prefix-p prefix bare))
        (string-remove-prefix prefix bare)
      bare)))

(defun p/size-modules ()
  "Return an alist of module name to absolute path, for `:directories'.
A directory name is relative to the repository root, and `.' is allowed so
that a package whose entry point sits in the root can count it as a module
of its own.  A directory that does not exist contributes nothing rather
than an error: policy names a layout, and an empty layout is a tree this
package has not written yet."
  (let ((root (p/repo-root)))
    (seq-mapcat (lambda (dir)
                  (mapcar (lambda (file) (cons (p/size-name file) file))
                          (p/dir-el-files (expand-file-name dir root))))
                (p/size-option :directories))))

(defun p/size-lines-in (file)
  "Return how many lines FILE has."
  (with-temp-buffer
    (insert-file-contents file)
    (count-lines (point-min) (point-max))))

(defun p/size-definitions-in (file)
  "Return how many definitions belong to FILE, or nil when nothing counts."
  (and p/size-definitions (funcall p/size-definitions file)))

(defun p/size-sum (numbers)
  "Return the sum of NUMBERS, and zero when there are none."
  (seq-reduce #'+ numbers 0))

(defun p/size-report ()
  "Print each module's size and the runs of lines it shares with another.
Return how many runs were printed.  Nothing here is a failure: the number
of runs is for a caller that wants it, not a status."
  (let* ((modules (p/size-modules))
         (sizes (mapcar (lambda (module)
                          (list (car module)
                                (p/size-lines-in (cdr module))
                                (p/size-definitions-in (cdr module))))
                        modules))
         (ordered (sort (copy-sequence sizes)
                        (lambda (a b) (> (nth 1 a) (nth 1 b)))))
         (counted p/size-definitions)
         (index (p/size-index modules))
         (runs (p/size-longest (p/size-runs (car index) (cdr index))))
         (lengths (mapcar (lambda (run) (nth 4 run)) runs)))
    (princ (format "size: %d lines in %d modules%s\n"
                   (p/size-sum (mapcar (lambda (e) (nth 1 e)) sizes))
                   (length sizes)
                   (if counted
                       (format ", %d definitions"
                               (p/size-sum (mapcar (lambda (e) (or (nth 2 e) 0))
                                                   sizes)))
                     "")))
    (when (car ordered)
      (princ (format "size: largest %s, %d lines%s\n"
                     (nth 0 (car ordered))
                     (nth 1 (car ordered))
                     (if counted
                         (format " and %d definitions"
                                 (or (nth 2 (car ordered)) 0))
                       ""))))
    (let* ((large (p/size-option :large))
           (big (seq-filter (lambda (e) (>= (nth 1 e) large)) ordered)))
      (when big
        (princ (format "size: %d over %d lines: %s\n"
                       (length big)
                       large
                       (mapconcat (lambda (e)
                                    (format "%s %d" (p/size-brief (nth 0 e))
                                            (nth 1 e)))
                                  big ", ")))))
    (princ (format (concat "size: %d run%s of %d lines or more, "
                           "%d lines in them, longest %d\n")
                   (length runs)
                   (if (= (length runs) 1) "" "s")
                   (p/size-option :window)
                   (p/size-sum lengths)
                   (if lengths (apply #'max lengths) 0)))
    (dolist (run (seq-take runs (p/size-option :shown)))
      (princ (format "size: %2d  %s:%d and %s:%d  %s\n"
                     (nth 4 run)
                     (nth 0 run) (nth 1 run)
                     (nth 2 run) (nth 3 run)
                     (nth 5 run))))
    (when (> (length runs) (p/size-option :shown))
      (princ (format "size: %d more runs, not shown\n"
                     (- (length runs) (p/size-option :shown)))))
    (length runs)))

(defun p/size-load-project ()
  "Load the package's own counting, when it has any.
`config/size.el' sits next to the policy it complements and may set
`p/size-definitions'.  Nothing is written for you: an empty file is a worse
reminder than the sentence in `config/ci.el'."
  (let* ((here (file-name-directory (or load-file-name buffer-file-name)))
         (project (expand-file-name "../config/size.el" here)))
    (when (file-exists-p project)
      (load project nil t))))

(p/size-load-project)

(defun p/size-main ()
  "Print the report and return the exit status, which is always zero.
A report that fails is a budget, and this suite keeps none for size: see
the Commentary for why."
  (p/size-report)
  0)

(provide 'size)

;;; size.el ends here
