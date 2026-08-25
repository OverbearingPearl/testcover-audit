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
(require 'testcover)
(eval-when-compile (require 'edebug))

(defvar testcover-audit-core--loaded-files nil
  "Alist mapping file names to function coverage entries.")

(defvar testcover-audit-core--initial-vectors (make-hash-table :test 'eq)
  "Baseline coverage vectors captured after instrumentation.

Keys are symbols, values are the coverage vector recorded right after
`testcover-start' or `testcover-this-defun'.  Definitions without a
baseline were not instrumented under testcover-audit and are excluded
from statistics.")

(defun testcover-audit-core--capture-initial-vectors (&rest _)
  "Store current testcover vectors as the delta baseline.
The arguments are those passed to `testcover-start' or
`testcover-this-defun' and are ignored."
  (dolist (form-data edebug-form-data)
    (let* ((sym (edebug--form-data-name form-data))
           (coverage (and sym (get sym 'edebug-coverage))))
      (when (and sym coverage
                 (eq (get sym 'edebug-behavior) 'testcover))
        (puthash sym (copy-sequence coverage)
                 testcover-audit-core--initial-vectors)))))

(unless (advice-member-p #'testcover-audit-core--capture-initial-vectors
                         'testcover-start)
  (advice-add 'testcover-start :after
              #'testcover-audit-core--capture-initial-vectors))
(unless (advice-member-p #'testcover-audit-core--capture-initial-vectors
                         'testcover-this-defun)
  (advice-add 'testcover-this-defun :after
              #'testcover-audit-core--capture-initial-vectors))

(defun testcover-audit-core--delta-type (baseline current)
  "Classify a coverage slot from BASELINE to CURRENT.

BASELINE is the slot value captured immediately after instrumentation.
CURRENT is the same slot at report time.

Return `covered', `onevalue', `uncovered' or `ignored'.

Slots that do not represent test results are excluded: `noreturn' markers
and the `edebug-ok-coverage' before markers written by testcover during
instrumentation.  A slot whose CURRENT differs from BASELINE was executed
by tests; its current value then decides `covered' vs `onevalue'."
  (cond
   ((and (consp baseline) (eq (car baseline) 'noreturn)) 'ignored)
   ((eq baseline 'edebug-ok-coverage) 'ignored)
   ((equal baseline current) 'uncovered)
   ((eq current 'edebug-ok-coverage) 'covered)
   (t 'onevalue)))

(defun testcover-audit-core--collect-stats (coverage baseline)
  "Parse COVERAGE vector against BASELINE and return statistics.

BASELINE is the vector captured right after instrumentation; COVERAGE
is the current vector.  Returns a plist with keys :total, :covered,
:onevalue, :uncovered and :percent."
  (unless (and baseline (vectorp baseline))
    (user-error "No baseline coverage for function; instrument after loading testcover-audit"))
  (let* ((vec (if (vectorp coverage) coverage (vconcat coverage)))
         (base (if (vectorp baseline) baseline (vconcat baseline)))
         (len (min (length vec) (length base)))
         (total 0)
         (onevalue 0)
         (covered 0)
         (uncovered 0)
         (ignored 0))
    (dotimes (i len)
      (cl-case (testcover-audit-core--delta-type (aref base i) (aref vec i))
        (onevalue (cl-incf onevalue) (cl-incf total))
        (covered  (cl-incf covered) (cl-incf total))
        (uncovered (cl-incf uncovered) (cl-incf total))
        (ignored (cl-incf ignored))))
    (list :total total
          :covered covered
          :onevalue onevalue
          :uncovered uncovered
          :ignored ignored
          :percent (testcover-audit-core--percent (+ covered onevalue) total))))

(defun testcover-audit-core--file-function-stats (file-entry)
  "Return one stats plist per covered function in FILE-ENTRY.
Functions without a captured baseline are omitted."
  (delq nil
        (mapcar (lambda (entry)
                  (let* ((sym (car entry))
                         (baseline (gethash sym testcover-audit-core--initial-vectors))
                         (current (cdr entry)))
                    (and baseline
                         (append (list :name (symbol-name sym))
                                 (testcover-audit-core--collect-stats
                                  current baseline)))))
                (cdr file-entry))))

(defun testcover-audit-core--file-stats (file)
  "Return aggregate coverage statistics for FILE from collected data."
  (let ((entry (assoc file testcover-audit-core--loaded-files)))
    (when entry
      (let ((fn-stats (testcover-audit-core--file-function-stats entry)))
        (and fn-stats (testcover-audit-core--aggregate fn-stats))))))

(defun testcover-audit-core--all-files-stats ()
  "Return aggregate coverage stats for all collected files.

Return nil when no coverage data has been collected."
  (let ((collected
         (delq nil
               (mapcar (lambda (entry)
                         (testcover-audit-core--file-stats (car entry)))
                       testcover-audit-core--loaded-files))))
    (and collected (testcover-audit-core--aggregate collected))))

(defun testcover-audit-core--function-stats (file)
  "Return per-function coverage statistics for FILE."
  (let ((entry (assoc file testcover-audit-core--loaded-files)))
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
