;;; testcover-audit-report.el --- Report rendering for testcover-audit -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Commands and functions for displaying coverage reports in buffers
;; and the echo area.

;;; Code:

(require 'testcover-audit-options)
(require 'testcover-audit-core)
(require 'testcover-audit-scan)
(require 'cl-lib)

(defun testcover-audit-report--stats-for-file (file)
  "Return coverage stats for FILE if data has been collected.

Prefer the current buffer's coverage vector (found via
`testcover-audit--buffer-coverage'); otherwise use
`testcover-audit-core--file-stats' which looks into
`testcover-audit--loaded-files'.  Return nil when no data is available."
  (let* ((key (and file (file-truename (expand-file-name file))))
         (stats (and key (testcover-audit-core--file-stats key))))
    stats))

(defun testcover-audit-report--show-stats ()
  "Show brief coverage statistics for the current buffer."
  (let* ((file (buffer-file-name))
         (stats (testcover-audit-report--stats-for-file file)))
    (if stats
        (message "Coverage: %d%% (%d/%d)"
                 (plist-get stats :percent)
                 (plist-get stats :covered)
                 (plist-get stats :total))
      (message "No coverage data for %s.  Run `testcover-start', run your tests, then `testcover-audit-scan-directory'."
               (or file "(buffer)")))))

(defun testcover-audit-report--show-all-stats ()
  "Show detailed coverage report in a dedicated buffer."
  (let* ((file (buffer-file-name))
         (stats (testcover-audit-report--stats-for-file file)))
    (if (null stats)
        (message "No coverage data for %s.\nRun `testcover-start', run your tests, then `testcover-audit-scan-directory'."
                 (or file "(buffer)"))
      (with-current-buffer (get-buffer-create "*Testcover Audit Report*")
        (erase-buffer)
        (insert (testcover-audit-report--format-table
                 (list (list "File" (or file "(none)"))
                       (list "Total forms" (plist-get stats :total))
                       (list "Covered" (plist-get stats :covered))
                       (list "1value" (plist-get stats :onevalue))
                       (list "Uncovered" (plist-get stats :uncovered))
                       (list "Coverage %" (plist-get stats :percent)))))
        (display-buffer (current-buffer))))))

(defun testcover-audit-report--show-function-stats ()
  "Show per-function coverage report."
  (let* ((file (buffer-file-name))
         (rows (and file (testcover-audit-core--function-stats
                          (file-truename (expand-file-name file))))))
    (if (null rows)
        (message "No coverage data for %s.\nRun `testcover-start', run your tests, then `testcover-audit-scan-directory'."
                 (or file "(buffer)"))
      (with-current-buffer (get-buffer-create "*Testcover Function Report*")
        (erase-buffer)
        (insert (testcover-audit-report--format-table
                 (mapcar (lambda (s)
                           (list (plist-get s :name)
                                 (plist-get s :percent)))
                         rows)))
        (display-buffer (current-buffer))))))

(defun testcover-audit-report--batch-report ()
  "Show coverage report for all instrumented files."
  (if (null testcover-audit--loaded-files)
      (message "No coverage data collected.\nRun `testcover-start', run your tests, then `testcover-audit-scan-directory'.")
    (let ((stats (testcover-audit-core--all-files-stats)))
      (with-current-buffer (get-buffer-create "*Testcover Batch Report*")
        (erase-buffer)
        (insert (testcover-audit-report--format-table
                 (list (list "Files" (length testcover-audit--loaded-files))
                       (list "Total forms" (plist-get stats :total))
                       (list "Covered" (plist-get stats :covered))
                       (list "1value" (plist-get stats :onevalue))
                       (list "Uncovered" (plist-get stats :uncovered))
                       (list "Coverage %" (plist-get stats :percent)))))
        (display-buffer (current-buffer))))))

(defun testcover-audit-report--format-table (rows)
  "Format ROWS as an aligned table string."
  (let ((width0 0)
        (width1 0)
        (lines))
    ;; Compute widths.
    (dolist (row rows)
      (let ((cell0 (prin1-to-string (nth 0 row)))
            (cell1 (prin1-to-string (nth 1 row))))
        (when (> (length cell0) width0)
          (setq width0 (length cell0)))
        (when (> (length cell1) width1)
          (setq width1 (length cell1)))))
    ;; Build lines.
    (dolist (row rows)
      (let ((cell0 (prin1-to-string (nth 0 row)))
            (cell1 (prin1-to-string (nth 1 row))))
        (push (format (concat "%-" (number-to-string width0) "s  %-"
                              (number-to-string width1) "s")
                      cell0 cell1)
              lines)))
    (mapconcat #'identity (nreverse lines) "\n")))

(defun testcover-audit-report--face-for-percent (percent)
  "Return the face appropriate for PERCENT according to thresholds."
  (cond ((>= percent testcover-audit-green-threshold)
         'success)
        ((>= percent testcover-audit-yellow-threshold)
         'warning)
        (t 'error)))

(provide 'testcover-audit-report)
;;; testcover-audit-report.el ends here
