;;; testcover-audit.el --- Quantitative coverage statistics for testcover.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; Version: 0.1.12
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
;;     Open a detailed report buffer with color-coded overall and
;;     function-level statistics for the current file.
;;     In the report, RET on a function row opens that function's stats.
;;
;;   testcover-audit-show-function-stats
;;     Show per-function coverage, including line-level breakdown when
;;     Edebug position data is available.
;;
;;   testcover-audit-batch-report
;;     Show an aggregate table for all instrumented files, with
;;     per-file and low-coverage function breakdown.
;;     RET on a file row opens its stats; RET on a function row opens
;;     that function's stats.
;;
;; Report buffers support j/n (down) and k/p (up) for row navigation.
;;
;;   testcover-audit-scan-directory
;;     Collect coverage from instrumented definitions in open source buffers.
;;
;;   testcover-audit-project-report
;;     Collect coverage from instrumented definitions in the current project.
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
;; Command groups:
;;   - Daily use: testcover-audit-show-stats, show-all-stats,
;;     show-function-stats, batch-report, project-report, scan-directory
;;   - Export/CI: testcover-audit-export-org, export-json, ci-check
;;   - Tooling: testcover-audit-instrument-directory
;;
;; The number of commands is manageable because each group has a clear
;; purpose.  For daily work, `testcover-audit-project-report' and the
;; `show-*' series are sufficient.
;;
;; All user-facing configuration is grouped under `testcover-audit'.
;;
;; Internal development helper (`testcover-audit--reload-modules') is not
;; part of the user-facing API.  The batch test runner is provided by
;; `testcover-audit-test.el' (see `testcover-audit-test-run').

;;; Code:

(defvar testcover-audit--package-root
  (or (and load-file-name (file-name-directory load-file-name))
      default-directory)
  "Root directory of testcover-audit package source.")

(when testcover-audit--package-root
  (add-to-list 'load-path (expand-file-name "lisp" testcover-audit--package-root)))

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
      (progn
        (setq-local testcover-audit--saved-mode-line-format
                    (and (local-variable-p 'mode-line-format)
                         mode-line-format))
        (testcover-audit--refresh-mode-line))
    (when (boundp 'testcover-audit--saved-mode-line-format)
      (if testcover-audit--saved-mode-line-format
          (setq-local mode-line-format
                      testcover-audit--saved-mode-line-format)
        (kill-local-variable 'mode-line-format))
      (kill-local-variable 'testcover-audit--saved-mode-line-format)
      (force-mode-line-update))))

(defvar-local testcover-audit--saved-mode-line-format nil
  "Mode-line format saved before enabling `testcover-audit-mode'.")

(defun testcover-audit--refresh-mode-line ()
  "Refresh the mode line to show coverage statistics."
  (let* ((stats (testcover-audit-report--stats-for-file (buffer-file-name)))
         (percent (and stats (plist-get stats :percent)))
         (coverage-str (cond ((null percent) "--")
                             (t (format "%d%%" percent))))
         (face (cond ((null percent) 'default)
                     (t (testcover-audit-report--face-for-percent percent)))))
    (setq mode-line-format
          (list (propertize (concat " PCTcov " coverage-str)
                            'face face
                            'help-echo "testcover-audit coverage")
                (default-value 'mode-line-format)))
    (force-mode-line-update)))

(defun testcover-audit--reload-modules ()
  "Reload testcover-audit modules for updated code."
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

;; The following commands are defined in the main module as the
;; single entry point for user-facing API.  Submodules keep the
;; non‑interactive implementations with internal double-dash names;
;; these wrappers add the `interactive' spec that makes them
;; invokable with M-x.

;;;###autoload
(defun testcover-audit-export-org (file)
  "Export current or batch report to Org file FILE."
  (interactive "FExport to Org file: ")
  (testcover-audit-export--export-org file))

;;;###autoload
(defun testcover-audit-export-json (file)
  "Export machine-readable report to JSON file FILE."
  (interactive "FExport to JSON file: ")
  (testcover-audit-export--export-json file))

;;;###autoload
(defun testcover-audit-ci-check ()
  "Exit with non-zero status if coverage is below threshold.

Intended for use in CI pipelines."
  (interactive)
  (testcover-audit-export--ci-check))

;;;###autoload
(defun testcover-audit-show-stats ()
  "Show brief coverage statistics for the current buffer."
  (interactive)
  (testcover-audit-report--show-stats))

;;;###autoload
(defun testcover-audit-show-all-stats ()
  "Show detailed coverage report in a dedicated buffer."
  (interactive)
  (testcover-audit-report--show-all-stats))

;;;###autoload
(defun testcover-audit-show-function-stats ()
  "Show per-function coverage report."
  (interactive)
  (testcover-audit-report--show-function-stats))

;;;###autoload
(defun testcover-audit-batch-report ()
  "Show coverage report for all instrumented files."
  (interactive)
  (testcover-audit-report--batch-report))

;;;###autoload
(defun testcover-audit-instrument-directory (directory)
  "Instrument source files under DIRECTORY with `testcover-start'."
  (interactive "DInstrument source directory: ")
  (testcover-audit-scan--instrument-directory directory))

;;;###autoload
(defun testcover-audit-scan-directory (directory)
  "Recursively scan DIRECTORY and collect coverage data."
  (interactive "DDirectory: ")
  (testcover-audit-scan--scan-directory directory))

;;;###autoload
(defun testcover-audit-project-report ()
  "Collect and display existing testcover data for the current project root."
  (interactive)
  (testcover-audit-report--project-report))

(provide 'testcover-audit)
;;; testcover-audit.el ends here
