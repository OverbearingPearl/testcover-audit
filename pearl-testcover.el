;;; pearl-testcover.el --- Quantitative coverage statistics for testcover.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/pearl-testcover
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (project "0.9.8"))
;; Keywords: tools, test, coverage
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; pearl-testcover adds quantitative coverage statistics to Emacs'
;; built-in testcover.el.  It shows coverage percentage, counts of
;; covered, uncovered and 1value forms, and can generate per-function
;; and per-file reports.

;;; Code:

(eval-and-compile
  (defvar pearl-testcover--package-root
    (or (and load-file-name (file-name-directory load-file-name))
        default-directory)
    "Root directory of Pearl-Testcover package source.")
  (add-to-list 'load-path
               (expand-file-name "lisp" pearl-testcover--package-root)))

(require 'pearl-testcover-options)
(require 'pearl-testcover-core)
(require 'pearl-testcover-report)
(require 'pearl-testcover-scan)
(require 'pearl-testcover-export)
(require 'pearl-testcover-ert)

;;;###autoload
(define-minor-mode pearl-testcover-mode
  "Toggle display of coverage percentage in the current buffer.

When enabled, pearl-testcover shows the test coverage percentage of
the current buffer in the mode line."
  :lighter " PTcov"
  :global nil
  (if pearl-testcover-mode
      (pearl-testcover--refresh-mode-line)
    (kill-local-variable 'mode-line-format)))

(defun pearl-testcover--refresh-mode-line ()
  "Refresh the mode line to show coverage statistics."
  ;; TODO: Implement mode line construction from collected stats.
  )

(defun pearl-testcover-reload-modules ()
  "Reload Pearl-Testcover modules for updated code."
  (interactive)
  (let* ((root-dir pearl-testcover--package-root)
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
    ;; Unload pearl-testcover.el if loaded
    (when (featurep 'pearl-testcover)
      (condition-case nil
          (unload-feature 'pearl-testcover)
        (error nil)))
    ;; Auto-clear all pearl-testcover keymap variables
    (mapatoms (lambda (sym)
                (when (and (string-match-p "^pearl-testcover-.*-mode-map$" (symbol-name sym))
                           (boundp sym))
                  (makunbound sym))))
    ;; Load pearl-testcover.el from root directory
    (let ((pearl-testcover-el (expand-file-name "pearl-testcover.el" root-dir)))
      (when (file-exists-p pearl-testcover-el)
        (load-file pearl-testcover-el)))
    ;; Load .el source files from lisp directory, ignoring .elc and test files
    (dolist (file el-files)
      (when (and (string-match "^[^.]+\\.el$" file)
                 (not (string-match "-test\\.el$" file)))
        (let ((el-path (expand-file-name file lisp-dir)))
          (load-file el-path))))
    (message "Pearl-Testcover modules reloaded.")))

(defun pearl-testcover-run-tests ()
  "Run all Pearl-Testcover test suites."
  (interactive)
  (require 'ert)
  (ert-delete-all-tests)
  ;; Reload all modules first to ensure latest code is used
  (pearl-testcover-reload-modules)
  ;; Load test files automatically from the lisp directory
  (let ((test-dir (expand-file-name "lisp" pearl-testcover--package-root)))
    (dolist (file (directory-files test-dir nil "pearl-testcover-.*-test\\.el$"))
      (let ((full-path (expand-file-name file test-dir)))
        (when (file-exists-p full-path)
          (load-file full-path)))))
  ;; Use batch-compatible function to ensure output is visible in terminal
  (if noninteractive
      (ert-run-tests-batch-and-exit)
    (ert t)))

(provide 'pearl-testcover)
;;; pearl-testcover.el ends here
