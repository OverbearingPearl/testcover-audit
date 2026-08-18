;;; testcover-audit.el --- Quantitative coverage statistics for testcover.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (project "0.9.8"))
;; Keywords: tools, test, coverage
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; testcover-audit adds quantitative coverage statistics to Emacs'
;; built-in testcover.el.  It shows coverage percentage, counts of
;; covered, uncovered and 1value forms, and can generate per-function
;; and per-file reports.
;;
;; The package provides the following user-facing commands:
;;
;;   testcover-audit-show-stats
;;     Display a brief coverage summary in the echo area.
;;
;;   testcover-audit-show-all-stats
;;     Open a detailed report buffer with color-coded statistics.
;;
;;   testcover-audit-show-function-stats
;;     Group coverage data by function to locate uncovered logic.
;;
;;   testcover-audit-batch-report
;;     Show an aggregate table for all instrumented files.
;;
;;   testcover-audit-scan-directory
;;     Recursively instrument all .el files in a directory.
;;
;;   testcover-audit-project-report
;;     Run a full coverage analysis for the current project.
;;
;;   testcover-audit-export-org
;;     Export a report in Org syntax.
;;
;;   testcover-audit-export-json
;;     Export a machine-readable JSON report.
;;
;;   testcover-audit-ci-check
;;     Return a non-zero exit status when coverage is below a threshold.
;;
;; Enable testcover-audit-mode to display the current buffer's coverage
;; percentage in the mode line.  Enable testcover-audit-ert-mode to
;; automatically generate a report after each ERT test run.
;;
;; All user-facing configuration is grouped under `testcover-audit'.

;;; Code:

(eval-and-compile
  (defvar testcover-audit--package-root
    (or (and load-file-name (file-name-directory load-file-name))
        default-directory)
    "Root directory of testcover-audit package source.")
  (add-to-list 'load-path
               (expand-file-name "lisp" testcover-audit--package-root)))

(require 'testcover-audit-options)
(require 'testcover-audit-core)
(require 'testcover-audit-report)
(require 'testcover-audit-scan)
(require 'testcover-audit-export)
(require 'testcover-audit-ert)

;;;###autoload
(define-minor-mode testcover-audit-mode
  "Toggle display of coverage percentage in the current buffer.

When enabled, testcover-audit shows the test coverage percentage of
the current buffer in the mode line."
  :lighter " PTcov"
  :global nil
  (if testcover-audit-mode
      (testcover-audit--refresh-mode-line)
    (kill-local-variable 'mode-line-format)))

(defun testcover-audit--refresh-mode-line ()
  "Refresh the mode line to show coverage statistics."
  ;; TODO: Implement mode line construction from collected stats.
  )

(defun testcover-audit-reload-modules ()
  "Reload testcover-audit modules for updated code."
  (interactive)
  (let* ((root-dir testcover-audit--package-root)
         (lisp-dir (expand-file-name "lisp" root-dir))
         (el-files (directory-files lisp-dir nil "\\.el$")))
    ;; Unload all features first
    (dolist (file el-files)
      (when (string-match "^[^.]+\\.el$" file)
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

(defun testcover-audit-run-tests ()
  "Run all testcover-audit test suites."
  (interactive)
  (require 'ert)
  (ert-delete-all-tests)
  ;; Reload all modules first to ensure latest code is used
  (testcover-audit-reload-modules)
  ;; Load test files automatically from the lisp directory
  (let ((test-dir (expand-file-name "lisp" testcover-audit--package-root)))
    (dolist (file (directory-files test-dir nil "testcover-audit-.*-test\\.el$"))
      (let ((full-path (expand-file-name file test-dir)))
        (when (file-exists-p full-path)
          (load-file full-path)))))
  ;; Use batch-compatible function to ensure output is visible in terminal
  (if noninteractive
      (ert-run-tests-batch-and-exit)
    (ert t)))

(provide 'testcover-audit)
;;; testcover-audit.el ends here
