;;; testcover-audit-core.el --- Pure statistics engine for testcover-audit -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Pure functions for collecting and aggregating coverage statistics
;; from testcover.el's internal edebug-coverage vectors.

;;; Code:

(require 'cl-lib)

(defvar testcover-audit--loaded-files nil
  "Alist mapping file names to function coverage entries.")

(defun testcover-audit-core--coverage-type (val)
  "Return a symbol describing testcover coverage state VAL."
  (pcase val
    (`(noreturn . ,_) 'ignored)
    ('edebug-unknown 'uncovered)
    ('edebug-ok-coverage 'covered)
    ((or 'maybe 'testcover-1value) 'onevalue)
    (_ 'onevalue)))

(defun testcover-audit-core--collect-stats (coverage)
  "Parse COVERAGE vector and return statistics.

COVERAGE is the edebug-coverage vector produced by testcover.
Returns a plist with keys :total, :covered, :onevalue, :uncovered
and :percent."
  (let* ((vec (if (vectorp coverage) coverage (vconcat coverage)))
         (total (length vec))
         (onevalue 0)
         (covered 0)
         (uncovered 0)
         (ignored 0))
    (dotimes (i total)
      (cl-case (testcover-audit-core--coverage-type (aref vec i))
        (onevalue (cl-incf onevalue))
        (covered  (cl-incf covered))
        (uncovered (cl-incf uncovered))
        (ignored  (cl-incf ignored))))
    (setq total (- total ignored))
    (list :total total
          :covered covered
          :onevalue onevalue
          :uncovered uncovered
          :ignored ignored
          :percent (testcover-audit-core--percent (+ covered onevalue) total))))

(defun testcover-audit-core--file-function-stats (file-entry)
  "Return one stats plist per covered function in FILE-ENTRY."
  (mapcar (lambda (entry)
            (append (list :name (symbol-name (car entry)))
                    (testcover-audit-core--collect-stats (cdr entry))))
          (cdr file-entry)))

(defun testcover-audit-core--file-stats (file)
  "Return aggregate coverage statistics for FILE from collected data."
  (let ((entry (assoc file testcover-audit--loaded-files)))
    (when entry
      (testcover-audit-core--aggregate
       (testcover-audit-core--file-function-stats entry)))))

(defun testcover-audit-core--all-files-stats ()
  "Return aggregate coverage stats for all collected files.

Return nil when no coverage data has been collected."
  (when testcover-audit--loaded-files
    (testcover-audit-core--aggregate
     (mapcar (lambda (entry)
               (testcover-audit-core--file-stats (car entry)))
             testcover-audit--loaded-files))))

(defun testcover-audit-core--function-stats (file)
  "Return per-function coverage statistics for FILE."
  (let ((entry (assoc file testcover-audit--loaded-files)))
    (when entry
      (testcover-audit-core--file-function-stats entry))))

(defun testcover-audit-core--aggregate (stats-list)
  "Combine STATS-LIST, a list of stat plists, into a single summary."
  (let ((total 0)
        (covered 0)
        (onevalue 0)
        (uncovered 0)
        (ignored 0))
    (dolist (stats stats-list)
      (let ((tot (or (plist-get stats :total) 0))
            (cov (or (plist-get stats :covered) 0))
            (one (or (plist-get stats :onevalue) 0))
            (unc (or (plist-get stats :uncovered) 0))
            (ign (or (plist-get stats :ignored) 0)))
        (setq total (+ total tot))
        (setq covered (+ covered cov))
        (setq onevalue (+ onevalue one))
        (setq uncovered (+ uncovered unc))
        (setq ignored (+ ignored ign))))
    (list :total total
          :covered covered
          :onevalue onevalue
          :uncovered uncovered
          :ignored ignored
          :percent (testcover-audit-core--percent (+ covered onevalue) total))))

(defun testcover-audit-core--percent (covered total)
  "Calculate coverage percentage as integer given COVERED and TOTAL."
  (if (zerop total)
      100
    (floor (/ (+ (* 100 covered) (/ total 2)) total))))

(provide 'testcover-audit-core)
;;; testcover-audit-core.el ends here
