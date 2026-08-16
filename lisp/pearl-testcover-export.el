;;; pearl-testcover-export.el --- Org/JSON export and CI checks -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/pearl-testcover
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Export coverage reports to Org-mode and JSON formats, and provide
;; a CI-friendly exit code check.

;;; Code:

(require 'pearl-testcover-options)
(require 'pearl-testcover-core)
(require 'pearl-testcover-scan)

;;;###autoload
(defun pearl-testcover-export-org (file)
  "Export current or batch report to Org file FILE."
  (interactive "FExport to Org file: ")
  ;; TODO: Implement Org export.
  )

;;;###autoload
(defun pearl-testcover-export-json (file)
  "Export machine-readable report to JSON file FILE."
  (interactive "FExport to JSON file: ")
  ;; TODO: Implement JSON export.
  )

;;;###autoload
(defun pearl-testcover-ci-check ()
  "Exit with non-zero status if coverage is below threshold.

Intended for use in CI pipelines."
  (interactive)
  ;; TODO: Implement threshold check and exit code.
  )

(provide 'pearl-testcover-export)
;;; pearl-testcover-export.el ends here
