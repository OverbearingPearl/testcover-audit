;;; util-tests.el --- Shared helpers for testcover-audit tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Test-only helpers shared by the testcover-audit test suites: baseline
;; coverage vector construction.

;;; Code:

(require 'testcover-audit-core)

(defconst util-tests--1value (intern "testcover-1value")
  "Symbol used by testcover as a static 1value marker.")

(defun util-tests--unknown-baseline (vector)
  "Return a baseline vector of `edebug-unknown' matching VECTOR's length."
  (make-vector (length vector) 'edebug-unknown))

(defun util-tests--install-baselines (file-alist)
  "Install all-unknown baselines for every function in FILE-ALIST.
FILE-ALIST uses the same structure as `testcover-audit-core--loaded-files'."
  (let ((ht (make-hash-table :test 'eq)))
    (dolist (file-entry file-alist)
      (dolist (fn-entry (cdr file-entry))
        (let* ((sym (car fn-entry))
               (current (cdr fn-entry)))
          (puthash sym (util-tests--unknown-baseline current) ht))))
    (setq testcover-audit-core--initial-vectors ht)))

(defun util-tests--install-symbol-baseline (symbol vector)
  "Set SYMBOL's baseline to an all-unknown vector matching VECTOR's length."
  (unless (hash-table-p testcover-audit-core--initial-vectors)
    (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq)))
  (puthash symbol (util-tests--unknown-baseline vector)
           testcover-audit-core--initial-vectors))

(provide 'util-tests)

;;; util-tests.el ends here
