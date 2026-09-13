;;; testcover-audit-util-test.el --- Shared helpers for testcover-audit tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Test-only helpers shared by the testcover-audit test suites:
;; baseline coverage vector construction and module reloading for
;; `testcover-audit-test-run'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'seq)
(require 'testcover-audit-core)

(defconst testcover-audit-util-test--package-root
  (expand-file-name ".."
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Root directory of the testcover-audit package source.")

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

(defun testcover-audit-util-test--reload-modules ()
  "Reload testcover-audit modules for updated code.

Unload the package's non-test features, clear the report keymaps, then
load `testcover-audit.el' and every non-test source file under `lisp/'
again so that the next test run uses the latest code."
  (let* ((root-dir testcover-audit-util-test--package-root)
         (lisp-dir (expand-file-name "lisp" root-dir))
         (el-files (directory-files lisp-dir nil "\\.el$")))
    ;; Unload all features first
    (dolist (file el-files)
      (when (and (string-match "^[^.]+\\.el$" file)
                 (not (string-match "-test\\.el$" file)))
        (let ((feature (intern (file-name-base file))))
          (when (featurep feature)
            (condition-case nil
                (unload-feature feature)
              (error nil))))))
    ;; Unload testcover-audit.el if loaded
    (when (featurep 'testcover-audit)
      (condition-case nil
          (unload-feature 'testcover-audit)
        (error nil)))
    ;; Auto-clear all testcover-audit keymap variables
    (mapatoms (lambda (sym)
                (when (and (string-match-p "^testcover-audit-.*-mode-map$" (symbol-name sym))
                           (boundp sym))
                  (makunbound sym))))
    ;; Load testcover-audit.el from root directory
    (let ((testcover-audit-el (expand-file-name "testcover-audit.el" root-dir)))
      (when (file-exists-p testcover-audit-el)
        (load-file testcover-audit-el)))
    ;; Load .el source files from lisp directory, ignoring .elc and test files
    (dolist (file el-files)
      (when (and (string-match "^[^.]+\\.el$" file)
                 (not (string-match "-test\\.el$" file)))
        (let ((el-path (expand-file-name file lisp-dir)))
          (load-file el-path))))
    (message "testcover-audit modules reloaded.")))

(ert-deftest testcover-audit-util-test--reload-modules ()
  "Test reload-modules stubs load-file/unload-feature and reports success."
  (let (msg-captured)
    (cl-letf (((symbol-function 'unload-feature) (lambda (&rest _) nil))
              ((symbol-function 'load-file) (lambda (&rest _) nil))
              ((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) msg-captured))))
      (testcover-audit-util-test--reload-modules)
      (should (seq-some (lambda (m) (string-match-p "reloaded" m)) msg-captured)))))

(provide 'testcover-audit-util-test)

;;; testcover-audit-util-test.el ends here
