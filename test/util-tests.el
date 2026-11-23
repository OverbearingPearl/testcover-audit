;;; util-tests.el --- Shared helpers for testcover-audit tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Test-only helpers shared by the testcover-audit test suites: baseline
;; coverage vector construction.

;;; Code:

(require 'testcover-audit-core)

(defconst util-tests--1value (intern "testcover-1value")
  "Symbol used by testcover as a static 1value marker.")

(defvar util-tests--messages nil
  "Text returned by `util-tests--message-stub', newest first.
Each test that stubs `message' binds this, so nothing leaks from
one test into the next.")

(defun util-tests--message-stub (format-string &rest args)
  "Emulate `message', returning the text it would display.
ARGS are the arguments of FORMAT-STRING, as for `message' itself.
`message' passes FORMAT-STRING through `format-message', which
substitutes curved quotes for the grave ones; a stub built on
`format' hands back the unsubstituted text instead.  A call whose
arguments are all constants counts as 1-valued for testcover, so one
session recording both spellings makes the coverage run signal that a
constant form varied -- the stub may lie about nothing but display.

Also push the returned text onto `util-tests--messages'."
  (let ((text (apply #'format-message format-string args)))
    (push text util-tests--messages)
    text))

(defun util-tests--unknown-baseline (vector)
  "Return a baseline vector of `edebug-unknown' matching VECTOR's length."
  (make-vector (length vector) 'edebug-unknown))

(defun util-tests--baseline-table ()
  "Return the baseline table to record fixtures in, creating it if needed.

The table is never replaced: `testcover-audit-core--initial-vectors'
also holds the baselines captured for the real sources when the suite
runs under instrumentation, and a test run that swapped the table out
would leave the coverage report with nothing to compare against."
  (unless (hash-table-p testcover-audit-core--initial-vectors)
    (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq)))
  testcover-audit-core--initial-vectors)

(defun util-tests--install-baselines (file-alist)
  "Install all-unknown baselines for every function in FILE-ALIST.
FILE-ALIST uses the same structure as `testcover-audit-core--loaded-files'."
  (let ((ht (util-tests--baseline-table)))
    (dolist (file-entry file-alist)
      (dolist (fn-entry (cdr file-entry))
        (let* ((sym (car fn-entry))
               (current (cdr fn-entry)))
          (puthash sym (util-tests--unknown-baseline current) ht))))
    ht))

(defun util-tests--install-symbol-baseline (symbol vector)
  "Set SYMBOL's baseline to an all-unknown vector matching VECTOR's length."
  (puthash symbol (util-tests--unknown-baseline vector)
           (util-tests--baseline-table)))

(provide 'util-tests)

;;; util-tests.el ends here
