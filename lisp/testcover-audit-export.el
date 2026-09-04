;;; testcover-audit-export.el --- Org/JSON export and CI checks -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: DeepSeek:deepseek-v4-flash, GLM:glm-5.3-flash, Laguna:laguna-s-2.1
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Export coverage reports to Org-mode and JSON formats, and provide
;; a CI-friendly exit code check.

;;; Code:

(require 'testcover-audit-options)
(require 'testcover-audit-core)
(require 'testcover-audit-scan)

(defun testcover-audit-export--require-stats ()
  "Return aggregate coverage stats or signal `user-error'."
  (or (testcover-audit-core--all-files-stats)
      (user-error "No coverage data available")))

(defun testcover-audit-export--export-org (file)
  "Export current or batch report to Org file FILE."
  (let ((stats (testcover-audit-export--require-stats)))
    (with-temp-file file
      (insert (format "#+TITLE: testcover-audit Coverage Report\n\n"))
      (insert (format "* Total coverage: %d%%\n" (plist-get stats :percent)))
      (insert (format "** Total forms: %d\n" (plist-get stats :total)))
      (insert (format "   - Covered: %d\n" (plist-get stats :covered)))
      (insert (format "   - 1value: %d\n" (plist-get stats :onevalue)))
      (insert (format "   - Uncovered: %d\n" (plist-get stats :uncovered)))))
  (message "Wrote Org report to %s" file))

(defun testcover-audit-export--export-json (file)
  "Export machine-readable report to JSON file FILE."
  (require 'json)
  (let ((stats (testcover-audit-export--require-stats)))
    (with-temp-file file
      (insert (format "{\"total\":%d,\"covered\":%d,\"onevalue\":%d,\"uncovered\":%d,\"percent\":%d}"
                      (plist-get stats :total)
                      (plist-get stats :covered)
                      (plist-get stats :onevalue)
                      (plist-get stats :uncovered)
                      (plist-get stats :percent))))
    (message "Wrote JSON report to %s" file)))

(defun testcover-audit-export--ci-check ()
  "Exit with non-zero status if coverage is below threshold.

Intended for use in CI pipelines."
  (let* ((stats (testcover-audit-export--require-stats))
         (percent (plist-get stats :percent))
         (threshold testcover-audit-ci-threshold))
    (if (< percent threshold)
        (progn
          (message "Coverage too low: %d%% (threshold %d%%)" percent threshold)
          (when noninteractive
            (kill-emacs 1)))
      (message "Coverage OK: %d%%" percent))))

(provide 'testcover-audit-export)
;;; testcover-audit-export.el ends here
