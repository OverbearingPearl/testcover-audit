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
  "Return coverage stats for FILE.

Prefer live testcover data from the buffer visiting FILE; fall back
to the `testcover-audit--loaded-files' snapshot collected by
`testcover-audit-scan-directory'.  Return nil when no data is available."
  (let* ((key (and file (file-truename (expand-file-name file))))
         (stats (and key
                     (or (testcover-audit-scan--buffer-stats file)
                         (testcover-audit-core--file-stats key)))))
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
      (message "No coverage data for %s.  Run `testcover-start', run your tests, and keep the buffer open."
               (or file "(buffer)")))))

(defun testcover-audit-report--show-all-stats ()
  "Show detailed coverage report in a dedicated buffer."
  (let* ((file (buffer-file-name))
         (stats (testcover-audit-report--stats-for-file file)))
    (if (null stats)
        (message "No coverage data for %s.\nRun `testcover-start', run your tests, and keep the buffer open."
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
         (rows (and file
                    (or (testcover-audit-scan--buffer-function-stats file)
                        (testcover-audit-core--function-stats
                         (file-truename (expand-file-name file)))))))
    (if (null rows)
        (message "No coverage data for %s.\nRun `testcover-start', run your tests, and keep the buffer open."
                 (or file "(buffer)"))
      (with-current-buffer (get-buffer-create "*Testcover Function Report*")
        (erase-buffer)
        (insert (testcover-audit-report--format-table
                 (mapcar (lambda (s)
                           (list (plist-get s :name)
                                 (format "%d%%" (or (plist-get s :percent) 0))))
                         rows)))
        (display-buffer (current-buffer))))))

(defun testcover-audit-report--batch-report ()
  "Show a detailed coverage report for all instrumented files."
  (if (null testcover-audit--loaded-files)
      (message "No coverage data collected.\nRun `testcover-start', run your tests, then `testcover-audit-scan-directory'.")
    (let* ((entries (cl-remove-if #'null testcover-audit--loaded-files))
           (file-paths (mapcar (lambda (e) (if (stringp e) e (car e))) entries))
           (file-names (mapcar #'file-relative-name file-paths))
           (file-width (max 10 (if file-names
                                    (apply #'max (mapcar #'length file-names))
                                  10)))
           (stats (testcover-audit-core--all-files-stats))
           (total (plist-get stats :total))
           (covered (plist-get stats :covered))
           (onevalue (plist-get stats :onevalue))
           (uncovered (plist-get stats :uncovered))
           (percent (plist-get stats :percent)))
      (if (null entries)
          (message "No coverage data collected.\nRun `testcover-start', run your tests, then `testcover-audit-scan-directory'.")
        (with-current-buffer (get-buffer-create "*Testcover Batch Report*")
          (erase-buffer)
          (insert "Testcover Audit Batch Report\n\n")
          (insert "Overall\n")
          (insert (format "  Files           %d\n" (length entries)))
          (insert (format "  Total forms     %d\n" total))
          (insert (format "  Covered         %d\n" covered))
          (insert (format "  1value          %d\n" onevalue))
          (insert (format "  Uncovered       %d\n" uncovered))
          (insert "  Coverage        ")
          (insert (propertize (format "%d%%" percent)
                              'face (testcover-audit-report--face-for-percent percent)))
          (insert "\n\nPer-file breakdown\n")
          (insert (format (format "%%-%ds %%10s %%10s %%10s %%10s %%10s\n" file-width)
                          "File" "Total" "Covered" "1value" "Uncovered" "Coverage"))
          (insert (make-string (+ file-width (* 5 11)) ?-))
          (insert "\n")
          (cl-loop for entry in entries
                   for fname in file-names
                   for fpath = (if (stringp entry) entry (car entry))
                   for key = (file-truename (expand-file-name fpath))
                   for fstats = (testcover-audit-core--file-stats key)
                   when fstats do
                   (let ((ftotal (plist-get fstats :total))
                         (fcov   (plist-get fstats :covered))
                         (fone   (plist-get fstats :onevalue))
                         (funcov (plist-get fstats :uncovered))
                         (fpercent (plist-get fstats :percent)))
                     (insert (format (format "%%-%ds %%10d %%10d %%10d %%10d " file-width)
                                     fname ftotal fcov fone funcov))
                     (insert (propertize (format "%10d%%" fpercent)
                                         'face (testcover-audit-report--face-for-percent fpercent)))
                     (insert "\n")))
          (let ((func-rows '()))
            (cl-loop for entry in entries
                     for fname in file-names
                     for fpath = (if (stringp entry) entry (car entry))
                     for key = (file-truename (expand-file-name fpath))
                     for fstats = (testcover-audit-core--file-stats key)
                     when fstats do
                     (let* ((funcs (or (testcover-audit-core--function-stats key) '()))
                            (low-funcs (cl-remove-if
                                        (lambda (s)
                                          (>= (or (plist-get s :percent) 0) 100))
                                        funcs)))
                       (dolist (s low-funcs)
                         (let ((pct (or (plist-get s :percent) 0))
                               (onevalue (or (plist-get s :onevalue) 0)))
                           (push (list fname
                                       (or (plist-get s :name) "<anonymous>")
                                       onevalue
                                       pct)
                                 func-rows)))))
            (setq func-rows
                  (sort func-rows
                        (lambda (a b)
                          (or (< (nth 3 a) (nth 3 b))
                              (and (= (nth 3 a) (nth 3 b))
                                   (string< (car a) (car b)))))))
            (when func-rows
              (insert "\nFunction-level breakdown\n")
              (let* ((func-file-width (max 8 (apply #'max (mapcar (lambda (r) (length (car r))) func-rows))))
                     (func-name-width (max 10 (apply #'max (mapcar (lambda (r) (length (nth 1 r))) func-rows))))
                     (header (format (format "%%-%ds %%-%ds %%10s %%10s"
                                             func-file-width func-name-width)
                                     "File" "Function" "1value" "Coverage")))
                (insert header "\n")
                (insert (make-string (length header) ?-) "\n")
                (dolist (row func-rows)
                  (insert (format (format "%%-%ds %%-%ds %%10d "
                                          func-file-width func-name-width)
                                  (car row) (nth 1 row) (nth 2 row)))
                  (insert (propertize (format "%10d%%" (nth 3 row))
                                      'face (testcover-audit-report--face-for-percent (nth 3 row))))
                  (insert "\n")))))
          (goto-char (point-min))
          (display-buffer (current-buffer)))))))

(defun testcover-audit-report--format-cell (value)
  "Return VALUE as a string for table display.
Strings are used verbatim; all other values use `prin1-to-string'."
  (if (stringp value)
      value
    (prin1-to-string value)))

(defun testcover-audit-report--format-table (rows)
  "Format ROWS as an aligned table string."
  (let ((width0 0)
        (width1 0)
        (lines))
    ;; Compute widths.
    (dolist (row rows)
      (let ((cell0 (testcover-audit-report--format-cell (nth 0 row)))
            (cell1 (testcover-audit-report--format-cell (nth 1 row))))
        (when (> (length cell0) width0)
          (setq width0 (length cell0)))
        (when (> (length cell1) width1)
          (setq width1 (length cell1)))))
    ;; Build lines.
    (dolist (row rows)
      (let ((cell0 (testcover-audit-report--format-cell (nth 0 row)))
            (cell1 (testcover-audit-report--format-cell (nth 1 row))))
        (push (format (format "%%-%ds  %%-%ds" width0 width1)
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
