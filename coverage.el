;;; coverage.el --- What the test suite reaches  -*- lexical-binding: t; -*-

;;; Commentary:

;; `make coverage' instruments the source, runs the ERT suite in a throwaway
;; Emacs, and prints what the tests reached: forms whose value varied, forms
;; that always took the same value, and forms that never ran.  It is a report,
;; not a gate.  Instrumentation changes what the code does -- every form gains
;; a wrapper that records a value -- so a suite with timing assertions can fail
;; here and pass in `make test'.  Correctness is the test job's verdict;
;; this one's is that a number exists to read.
;;
;; The measuring is testcover-audit, installed on first use like package-lint.
;; Where to look is the `:coverage' table of `ci/config.el'; the default is the
;; same source set as `:size', the modules under the submodule directory plus
;; the entry point at the root.  Test and vendored files are never
;; instrumented, whatever the table says.

;;; Code:

(require 'cl-lib)
(require 'deps)
(require 'ert)
(require 'json)
(require 'seq)
(require 'subr-x)

;; Bound below and read by testcover-audit when the report is built.  The
;; library is not loaded at this point: a package with no tests should not
;; download it just to discover there is nothing to measure.
(defvar testcover-audit-low-coverage-threshold)
(defvar testcover-audit-test-file-regexp)

(defun p/coverage-option (key)
  "Return the value for KEY in the :coverage policy table."
  (plist-get (p/config-value :coverage) key))

(defun p/coverage-source-files ()
  "Return the files to instrument, the entry point first.
The entry point is always first: instrumenting it evaluates its top-level
forms, and the modules it requires are instrumented afterwards.  A file that
is both the entry point and under a directory is counted once."
  (let ((root (p/repo-root))
        (files (list (p/main-file))))
    (dolist (dir (or (p/coverage-option :directories) '("lisp" ".")))
      (unless (equal dir ".")
        (setq files
              (append files
                      (p/recursive-el-files (expand-file-name dir root))))))
    (delete-dups (mapcar #'file-truename files))))

(defun p/coverage-add-load-path ()
  "Put the directories the test runner uses on `load-path'."
  (dolist (dir (list (p/repo-root) (p/submodule-dir) (p/test-dir)
                     (p/vendor-dir)))
    (add-to-list 'load-path dir))
  (dolist (dir (p/vendor-load-path))
    (add-to-list 'load-path dir)))

(defun p/coverage-instrument (files)
  "Instrument FILES, returning a (FILE . ERROR) for each file that signalled.
A file that cannot be instrumented has no coverage to report, and skipping it
would make the percentage a guess, so the caller stops instead."
  (let (failed)
    ;; `testcover' messages once per instrumented definition; a package's
    ;; several hundred definitions would bury the report they exist to make.
    (let ((inhibit-message t))
      (dolist (file files)
        (condition-case err
            (testcover-start file)
          (error (push (cons file (error-message-string err)) failed)))))
    (nreverse failed)))

(defun p/coverage-run-tests ()
  "Load the test files, run each test, and return what happened.
The value is (TOTAL UNEXPECTED FAILED ABORTS).  Tests run one at a time
rather than through `ert-run-tests-batch' because an assertion in a timer or
a process sentinel -- which instrumentation can turn from a race won into a
race lost -- signals outside ERT and aborts a batch run, losing every test
after it.  One at a time, that test is the only one affected, and the report
still covers the rest of the suite.  The files are loaded in the same order
the test runner uses, so a suite that depends on that order behaves the same
here."
  (dolist (file (p/dir-el-files (p/test-dir)))
    (load file nil t))
  (let ((total 0)
        (unexpected 0)
        failed
        aborts)
    (dolist (test (ert-select-tests t t))
      (let* ((name (ert-test-name test))
             (result nil)
             (stats (condition-case err
                        (ert-run-tests
                         name
                         (lambda (event &rest args)
                           (when (eq event 'test-ended)
                             (setq result (cadr args)))))
                      (error
                       (push (cons name (error-message-string err)) aborts)
                       nil))))
        (if stats
            (progn
              (setq total (+ total (ert-stats-total stats)))
              (let ((bad (ert-stats-completed-unexpected stats)))
                (when (> bad 0)
                  (setq unexpected (+ unexpected bad))
                  (push (cons name (and result
                                        (ert-reason-for-test-result result)))
                        failed))))
          ;; An error that escaped ERT is a failed test, counted once so the
          ;; summary does not read as a suite that shrank.
          (setq total (1+ total)
                unexpected (1+ unexpected)))))
    (list total unexpected (nreverse failed) (nreverse aborts))))

(defun p/coverage-skip-regexp (root)
  "Return a regexp matching the paths under ROOT that are not source.
The scan walks the whole repository because that is the only directory it
takes; test, vendored and cache files are excluded by path so the walk does
not spend its time on them."
  (regexp-opt
   (mapcar (lambda (dir)
             (file-name-as-directory (expand-file-name dir root)))
           (list (p/test-dir) (p/vendor-dir)
                 (expand-file-name ".cache" root)
                 (expand-file-name ".git" root)))))

(defun p/coverage-collect (root json-file)
  "Scan ROOT, print the per-file table, and write JSON-FILE.
The table comes from testcover-audit's own batch report so the artifact and
the interactive command show the same numbers.  The function-level breakdown
is suppressed: the file table is what a CI log can hold, and the JSON carries
the totals."
  (let ((default-directory root)
        (inhibit-message t)
        (testcover-audit-test-file-regexp
         (concat (p/coverage-skip-regexp root) "\\|"
                 testcover-audit-test-file-regexp))
        (testcover-audit-low-coverage-threshold 0))
    (testcover-audit-scan-directory root)
    (testcover-audit-batch-report)
    (when-let* ((buffer (get-buffer "*Testcover Batch Report*")))
      (princ (with-current-buffer buffer
               (buffer-substring-no-properties (point-min) (point-max)))))
    (make-directory (file-name-directory json-file) t)
    (testcover-audit-export-json json-file)))

(defun p/coverage-print-totals (json-file)
  "Print the totals in JSON-FILE and return the exit status.
Zero collected forms is a failure, not a report of zero coverage: it means
the scan found no instrumented definitions, and a percentage over an empty
set is not a number anybody should read."
  (let* ((json (json-read-file json-file))
         (total (alist-get 'total json))
         (covered (alist-get 'covered json))
         (onevalue (alist-get 'onevalue json))
         (uncovered (alist-get 'uncovered json))
         (percent (alist-get 'percent json)))
    (if (or (null total) (zerop total))
        (progn
          (princ "coverage: no coverage data was collected\n"
                 'external-debugging-output)
          1)
      (princ (format (concat "coverage: %d%% (covered %d, 1value %d,"
                             " uncovered %d, total %d)\n")
                     percent covered onevalue uncovered total))
      0)))

(defun p/coverage-main ()
  "Print the coverage report and return the exit status."
  (let ((root (file-name-as-directory (p/repo-root)))
        (json-file (expand-file-name "build/coverage.json" (p/repo-root))))
    (if (null (p/dir-el-files (p/test-dir)))
        (progn
          (princ "coverage: no test modules found; skipping\n")
          0)
      (p/ensure-package 'testcover-audit 'testcover-audit)
      (p/coverage-add-load-path)
      (let ((failed (p/coverage-instrument (p/coverage-source-files))))
        (if failed
            (progn
              (dolist (entry failed)
                (princ (format "coverage: cannot instrument %s: %s\n"
                               (car entry) (cdr entry))
                       'external-debugging-output))
              1)
          (let* ((run (p/coverage-run-tests))
                 (total (nth 0 run))
                 (unexpected (nth 1 run))
                 (failed (nth 2 run))
                 (aborts (nth 3 run)))
            (princ (format "coverage: ERT ran %d tests, %d unexpected\n"
                           total unexpected))
            (dolist (entry failed)
              (princ (format "coverage: failed %s: %s\n"
                             (car entry)
                             (or (car (split-string (or (cdr entry) "") "\n"))
                                 ""))))
            (dolist (entry aborts)
              (princ (format "coverage: aborted %s: %s\n"
                             (car entry)
                             (car (split-string (cdr entry) "\n")))))
            (p/coverage-collect root json-file)
            (p/coverage-print-totals json-file)))))))

(defun p/coverage-main-or-die ()
  "Run `p/coverage-main' and exit Emacs with the status it returns.
An error is written to stderr before exiting: batch mode would turn it into
a non-zero status by itself, but the message would be buried in a backtrace
nobody reads."
  (condition-case err
      (kill-emacs (p/coverage-main))
    (error
     (princ (format "coverage: %s\n" (error-message-string err))
            'external-debugging-output)
     (kill-emacs 1))))

(provide 'coverage)

;;; coverage.el ends here
