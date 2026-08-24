;;; testcover-audit-test.el --- Test entry point for testcover-audit -*- lexical-binding: t; -*-

;;; Commentary:

;; Batch test entry point for testcover-audit.  Provides
;; `testcover-audit-test-run' which loads all test files under the
;; `lisp/' directory and runs them with ERT.

;;; Code:

(require 'ert)

(defvar testcover-audit-test--package-root
  (or (and load-file-name (file-name-directory load-file-name))
      default-directory)
  "Root directory of testcover-audit package source.")

(add-to-list 'load-path testcover-audit-test--package-root)
(add-to-list 'load-path (expand-file-name "lisp" testcover-audit-test--package-root))

(require 'testcover-audit)

(defun testcover-audit-test-run ()
  "Run all testcover-audit test suites.
Loads test files from the `lisp/' directory, then runs ERT in
batch or interactive mode depending on `noninteractive'."
  (interactive)
  (ert-delete-all-tests)
  ;; Reload all modules first to ensure latest code is used
  (testcover-audit--reload-modules)
  ;; Load test files automatically from the lisp directory
  (let ((test-dir (expand-file-name "lisp" testcover-audit-test--package-root)))
    (dolist (file (directory-files test-dir nil "testcover-audit-.*-test\\.el$"))
      (let ((full-path (expand-file-name file test-dir)))
        (when (file-exists-p full-path)
          (load-file full-path)))))
  ;; Use batch-compatible function to ensure output is visible in terminal
  (if noninteractive
      (ert-run-tests-batch-and-exit)
    (ert t)))

(provide 'testcover-audit-test)
;;; testcover-audit-test.el ends here
