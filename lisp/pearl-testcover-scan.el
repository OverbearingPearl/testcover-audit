;;; pearl-testcover-scan.el --- Directory scanning and instrumentation -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/pearl-testcover
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Recursive scanning, dependency ordering and mass instrumentation
;; of Emacs Lisp files for coverage analysis.

;;; Code:

(require 'pearl-testcover-options)
(require 'pearl-testcover-core)

(defvar pearl-testcover--loaded-files nil
  "List of files currently instrumented by pearl-testcover.")

;;;###autoload
(defun pearl-testcover-scan-directory (directory)
  "Recursively scan DIRECTORY and instrument all .el files."
  (interactive "DDirectory: ")
  ;; TODO: Implement recursive scan and instrumentation.
  )

;;;###autoload
(defun pearl-testcover-project-report ()
  "Run coverage analysis for the current project root."
  (interactive)
  ;; TODO: Implement project.el integration.
  )

(defun pearl-testcover--dependency-order (files)
  "Order FILES by dependency (require) relationships."
  ;; TODO: Implement topological sort by requires.
  )

(provide 'pearl-testcover-scan)
;;; pearl-testcover-scan.el ends here
