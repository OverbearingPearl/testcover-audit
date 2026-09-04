;;; testcover-audit-options.el --- User options for testcover-audit -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: DeepSeek:deepseek-v4-flash, GLM:glm-5.3-flash, Laguna:laguna-s-2.1
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Customization group and user options for testcover-audit.

;;; Code:

(defgroup testcover-audit nil
  "Quantitative coverage statistics for testcover.el."
  :prefix "testcover-audit-"
  :group 'tools)

(defcustom testcover-audit-green-threshold 80
  "Coverage percentage at/above which reports are highlighted green."
  :type 'number
  :group 'testcover-audit)

(defcustom testcover-audit-yellow-threshold 50
  "Coverage percentage below which reports are highlighted red."
  :type 'number
  :group 'testcover-audit)

(defcustom testcover-audit-report-format 'table
  "Default report format.

When `table', reports use aligned tables.  When `list', each record is
rendered on one line with \"Label: value\" pairs, which is more
compact in narrow windows."
  :type '(choice (const table) (const list))
  :group 'testcover-audit)

(defcustom testcover-audit-low-coverage-threshold 100
  "Minimum coverage percentage for a function to appear in batch reports.

Functions with coverage below this value are listed in the
function-level breakdown.  The default 100 lists every function that
is not fully covered."
  :type 'number
  :group 'testcover-audit)

(defcustom testcover-audit-exclude-files '("^\\." "\\.elc$")
  "List of regexps used to exclude files from directory scans."
  :type '(repeat regexp)
  :group 'testcover-audit)

(defcustom testcover-audit-test-file-regexp
  "\\(?:\\`\\|[-_]\\)test\\.el\\'"
  "Regexp matching test files excluded from source coverage collection.

Set this to nil when test files themselves should be included in coverage."
  :type '(choice (const :tag "Do not exclude test files" nil) regexp)
  :group 'testcover-audit)

(defcustom testcover-audit-ert-scan-directory nil
  "Directory scanned before automatic ERT coverage reports.

When nil, `testcover-audit-ert-mode' does not scan automatically."
  :type '(choice directory (const :tag "Do not scan automatically" nil))
  :group 'testcover-audit)

(defcustom testcover-audit-auto-show-report nil
  "Whether to automatically display the report after ERT runs."
  :type 'boolean
  :group 'testcover-audit)

(defcustom testcover-audit-ci-threshold 80
  "Minimum coverage percentage required by `testcover-audit-ci-check'."
  :type 'number
  :group 'testcover-audit)

(provide 'testcover-audit-options)
;;; testcover-audit-options.el ends here
