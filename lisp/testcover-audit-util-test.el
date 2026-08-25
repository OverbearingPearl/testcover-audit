;;; testcover-audit-util-test.el --- Shared helpers for testcover-audit tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Test-only helpers for constructing baseline coverage vectors.

;;; Code:

(require 'testcover-audit-core)

(defconst testcover-audit-util-test--1value (intern "testcover-1value")
  "Symbol used by testcover as a static 1value marker.")

(defun testcover-audit-util-test--unknown-baseline (vector)
  "Return a baseline vector of `edebug-unknown' matching VECTOR's length."
  (make-vector (length vector) 'edebug-unknown))

(defun testcover-audit-util-test--install-baselines (file-alist)
  "Install all-unknown baselines for every function in FILE-ALIST.
FILE-ALIST uses the same structure as `testcover-audit-core--loaded-files'."
  (let ((ht (make-hash-table :test 'eq)))
    (dolist (file-entry file-alist)
      (dolist (fn-entry (cdr file-entry))
        (let* ((sym (car fn-entry))
               (current (cdr fn-entry)))
          (puthash sym (testcover-audit-util-test--unknown-baseline current) ht))))
    (setq testcover-audit-core--initial-vectors ht)))

(defun testcover-audit-util-test--install-symbol-baseline (symbol vector)
  "Set SYMBOL's baseline to an all-unknown vector matching VECTOR's length."
  (unless (hash-table-p testcover-audit-core--initial-vectors)
    (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq)))
  (puthash symbol (testcover-audit-util-test--unknown-baseline vector)
           testcover-audit-core--initial-vectors))

(provide 'testcover-audit-util-test)
;;; testcover-audit-util-test.el ends here
