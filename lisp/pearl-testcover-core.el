;;; pearl-testcover-core.el --- Pure statistics engine for pearl-testcover -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/pearl-testcover
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Pure functions for collecting and aggregating coverage statistics
;; from testcover.el's internal edebug-coverage vectors.

;;; Code:

(defun pearl-testcover--collect-stats (coverage)
  "Parse COVERAGE vector and return statistics.

COVERAGE is the edebug-coverage vector produced by testcover.
Returns a plist with keys :total, :covered, :onevalue, :uncovered
and :percent."
  ;; TODO: Implement parsing of edebug-coverage vector.
  )

(defun pearl-testcover--file-stats (file)
  "Return coverage statistics for FILE.

Loads FILE if needed and extracts coverage data.
Returns a plist like `pearl-testcover--collect-stats'."
  ;; TODO: Implement file-level aggregation.
  )

(defun pearl-testcover--function-stats (file)
  "Return per-function coverage statistics for FILE.

Returns a list of plists, one per function, with keys
:name, :total, :covered, :onevalue, :uncovered and :percent."
  ;; TODO: Implement function-level grouping.
  )

(defun pearl-testcover--aggregate (stats-list)
  "Combine STATS-LIST, a list of stat plists, into a single summary."
  ;; TODO: Implement aggregation of multiple stat plists.
  )

(defun pearl-testcover--percent (covered total)
  "Calculate coverage percentage as integer given COVERED and TOTAL."
  (if (zerop total)
      100
    (round (* 100.0 covered total))))

(provide 'pearl-testcover-core)
;;; pearl-testcover-core.el ends here
