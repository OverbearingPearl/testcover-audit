;;; pearl-testcover-options.el --- User options for pearl-testcover -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/pearl-testcover
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Customization group and user options for pearl-testcover.

;;; Code:

(defgroup pearl-testcover nil
  "Quantitative coverage statistics for testcover.el."
  :prefix "pearl-testcover-"
  :group 'tools)

(defcustom pearl-testcover-green-threshold 80
  "Coverage percentage at/above which reports are highlighted green."
  :type 'number
  :group 'pearl-testcover)

(defcustom pearl-testcover-yellow-threshold 50
  "Coverage percentage below which reports are highlighted red."
  :type 'number
  :group 'pearl-testcover)

(defcustom pearl-testcover-report-format 'table
  "Default report format.  Either `table' or `list'."
  :type '(choice (const table) (const list))
  :group 'pearl-testcover)

(defcustom pearl-testcover-exclude-files '("^\\." "\\.elc$")
  "List of regexps used to exclude files from directory scans."
  :type '(repeat regexp)
  :group 'pearl-testcover)

(defcustom pearl-testcover-auto-show-report nil
  "Whether to automatically display the report after ERT runs."
  :type 'boolean
  :group 'pearl-testcover)

(defcustom pearl-testcover-ci-threshold 80
  "Minimum coverage percentage required by `pearl-testcover-ci-check'."
  :type 'number
  :group 'pearl-testcover)

(provide 'pearl-testcover-options)
;;; pearl-testcover-options.el ends here
