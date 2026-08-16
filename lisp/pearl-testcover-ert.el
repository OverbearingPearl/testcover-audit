;;; pearl-testcover-ert.el --- ERT integration for pearl-testcover -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/pearl-testcover
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Integration with ERT so that coverage reports are generated
;; automatically after test runs.

;;; Code:

(require 'pearl-testcover-options)
(require 'pearl-testcover-report)

(defvar pearl-testcover-ert-after-run-hook nil
  "Hook run after an ERT test run completes.")

(defun pearl-testcover-ert--after-run ()
  "Function added to `ert-after-run-hook'."
  ;; TODO: Implement hook function.
  )

;;;###autoload
(define-minor-mode pearl-testcover-ert-mode
  "Automatically run coverage reports after ERT tests."
  :global t
  :lighter " PTert"
  (if pearl-testcover-ert-mode
      (add-hook 'ert-after-run-hook #'pearl-testcover-ert--after-run)
    (remove-hook 'ert-after-run-hook #'pearl-testcover-ert--after-run)))

(provide 'pearl-testcover-ert)
;;; pearl-testcover-ert.el ends here
