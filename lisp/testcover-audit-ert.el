;;; testcover-audit-ert.el --- ERT integration for testcover-audit -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Integration with ERT so that coverage reports are generated
;; automatically after test runs.

;;; Code:

(require 'ert)
(require 'testcover-audit-options)
(require 'testcover-audit-report)
(require 'testcover-audit-scan)

(defun testcover-audit-ert--after-run ()
  "Function added to `ert-after-run-hook'."
  (run-hooks 'testcover-audit-ert-after-run-hook)
  (when testcover-audit-auto-show-report
    (when testcover-audit-ert-scan-directory
      (testcover-audit-scan--scan-directory
       testcover-audit-ert-scan-directory))
    (testcover-audit-report--batch-report)))

(defvar testcover-audit-ert-after-run-hook nil
  "Hook run after an ERT test run completes.")

;;;###autoload
(define-minor-mode testcover-audit-ert-mode
  "Automatically run coverage reports after ERT tests."
  :global t
  :lighter " PTert"
  :group 'testcover-audit
  (if testcover-audit-ert-mode
      (add-hook 'ert-after-run-hook #'testcover-audit-ert--after-run)
    (remove-hook 'ert-after-run-hook #'testcover-audit-ert--after-run)))

(provide 'testcover-audit-ert)
;;; testcover-audit-ert.el ends here
