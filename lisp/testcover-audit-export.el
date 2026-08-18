;;; testcover-audit-export.el --- Org/JSON export and CI checks -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Export coverage reports to Org-mode and JSON formats, and provide
;; a CI-friendly exit code check.

;;; Code:

(require 'testcover-audit-options)
(require 'testcover-audit-core)
(require 'testcover-audit-scan)

;;;###autoload
(defun testcover-audit-export-org (file)
  "Export current or batch report to Org file FILE."
  (interactive "FExport to Org file: ")
  ;; TODO: Implement Org export.
  )

;;;###autoload
(defun testcover-audit-export-json (file)
  "Export machine-readable report to JSON file FILE."
  (interactive "FExport to JSON file: ")
  ;; TODO: Implement JSON export.
  )

;;;###autoload
(defun testcover-audit-ci-check ()
  "Exit with non-zero status if coverage is below threshold.

Intended for use in CI pipelines."
  (interactive)
  ;; TODO: Implement threshold check and exit code.
  )

(provide 'testcover-audit-export)
;;; testcover-audit-export.el ends here
