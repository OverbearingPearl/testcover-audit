;;; testcover-audit-scan.el --- Directory scanning and instrumentation -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Recursive scanning, dependency ordering and mass instrumentation
;; of Emacs Lisp files for coverage analysis.

;;; Code:

(require 'testcover-audit-options)
(require 'testcover-audit-core)

(defvar testcover-audit--loaded-files nil
  "List of files currently instrumented by testcover-audit.")

;;;###autoload
(defun testcover-audit-scan-directory (directory)
  "Recursively scan DIRECTORY and instrument all .el files."
  (interactive "DDirectory: ")
  ;; TODO: Implement recursive scan and instrumentation.
  )

;;;###autoload
(defun testcover-audit-project-report ()
  "Run coverage analysis for the current project root."
  (interactive)
  ;; TODO: Implement project.el integration.
  )

(defun testcover-audit--dependency-order (files)
  "Order FILES by dependency (require) relationships."
  ;; TODO: Implement topological sort by requires.
  )

(provide 'testcover-audit-scan)
;;; testcover-audit-scan.el ends here
