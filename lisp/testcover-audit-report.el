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

;; Report buffers are read-only and navigable.  RET on a file row opens
;; that file's detailed report; RET on a function row opens that
;; function's line-level report.  Use j/n to move down and k/p to move
;; up between rows.  A header line shows the available keys.

(require 'testcover-audit-options)
(require 'testcover-audit-core)
(require 'testcover-audit-scan)
(require 'cl-lib)

;;; Report buffer navigation

(defvar testcover-audit-report--navigation-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "j") #'next-line)
    (define-key map (kbd "k") #'previous-line)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "p") #'previous-line)
    map)
  "Keymap for moving between rows in report buffers.
Provides j/n (down) and k/p (up) bindings in addition to the
usual Emacs movement commands.")

;;; Rendering primitives

(defun testcover-audit-report--face-for-percent (percent)
  "Return the face appropriate for PERCENT according to thresholds."
  (cond ((>= percent testcover-audit-green-threshold)
         'success)
        ((>= percent testcover-audit-yellow-threshold)
         'warning)
        (t 'error)))

(defun testcover-audit-report--format-cell (value)
  "Return VALUE as a string for table display.
Strings are used verbatim; all other values use `prin1-to-string'."
  (if (stringp value)
      value
    (prin1-to-string value)))

(defun testcover-audit-report--format-table (rows)
  "Format ROWS as an aligned table string.

Each row is a list of cells.  Strings are inserted verbatim; all other
values are converted with `prin1-to-string'."
  (if (null rows)
      ""
    (let* ((num-cols (length (car rows)))
           (widths (make-vector num-cols 0)))
      (dolist (row rows)
        (dotimes (i num-cols)
          (let ((cell (testcover-audit-report--format-cell (nth i row))))
            (setf (aref widths i) (max (aref widths i) (length cell))))))
      (mapconcat
       (lambda (row)
         (mapconcat
          #'identity
          (cl-mapcar
           (lambda (width cell)
             (format (format "%%-%ds" width)
                     (testcover-audit-report--format-cell cell)))
           (append widths nil)
           row)
          "  "))
       rows
       "\n"))))

(defun testcover-audit-report--cell-string (cell type)
  "Return CELL as a string according to TYPE.
TYPE is `text', `number' or `percent'."
  (pcase type
    ('number (format "%d" (or cell 0)))
    ('percent (format "%d%%" (or cell 0)))
    (_ (testcover-audit-report--format-cell cell))))

(defun testcover-audit-report--format-table-row (string-row row specs widths)
  "Format table row STRING-ROW using ROW values, SPECS and WIDTHS.

SPECS is a list of (LABEL TYPE &optional FACE); WIDTHS are the
computed column widths; ROW holds the raw values for percent faces."
  (mapconcat
   (lambda (i)
     (let* ((spec (nth i specs))
            (type (nth 1 spec))
            (face (nth 2 spec))
            (width (nth i widths))
            (cell (nth i string-row)))
       (pcase type
         ('percent
          (propertize (format (format "%%%ds" width) cell)
                      'face (testcover-audit-report--face-for-percent
                             (nth i row))))
         ('number
          (format (format "%%%ds" width) cell))
         (_
          (let ((s (format (format "%%-%ds" width) cell)))
            (if face (propertize s 'face face) s))))))
   (number-sequence 0 (1- (length specs)))
   "  "))

(defun testcover-audit-report--insert-table (headers rows &optional row-props-fn)
  "Insert a formatted table with HEADERS specs and ROWS data.

Each HEADERS element is (LABEL TYPE &optional FACE) where TYPE is
`text', `number' or `percent'.  ROWS is a list of cell lists matching
the header count.  `number' and `percent' cells are right-aligned;
`text' cells are left-aligned, and are propertized with FACE when
given.  `percent' cells are colored by threshold.

When `testcover-audit-report-format' is `list', each row is rendered
as a single \"Label: value\" line instead of an aligned table.

ROW-PROPS-FN, when non-nil, is called with (ROW INDEX) and returns a
plist of navigation properties for that row (see
`testcover-audit-report--add-row-properties')."
  (if (eq testcover-audit-report-format 'list)
      (testcover-audit-report--insert-list-table headers rows row-props-fn)
    (let* ((num-cols (length headers))
           (widths (mapcar (lambda (spec) (length (car spec))) headers))
           (string-rows
            (mapcar
             (lambda (row)
               (cl-mapcar #'testcover-audit-report--cell-string
                          row (mapcar #'cadr headers)))
             rows)))
      (dolist (srow string-rows)
        (dotimes (i num-cols)
          (setf (nth i widths)
                (max (nth i widths) (length (nth i srow))))))
      (let ((header-line
             (mapconcat
              (lambda (i)
                (format (format "%%-%ds" (nth i widths))
                        (car (nth i headers))))
              (number-sequence 0 (1- num-cols))
              "  ")))
        (insert (propertize header-line 'face 'bold) "\n")
        (insert (make-string (length header-line) ?-) "\n"))
      (cl-loop for row in rows
               for srow in string-rows
               for idx from 0
               do (let ((start (point)))
                    (insert (testcover-audit-report--format-table-row
                             srow row headers widths))
                    (let ((end (point)))
                      (insert "\n")
                      (when row-props-fn
                        (let ((props (funcall row-props-fn row idx)))
                          (when props
                            (testcover-audit-report--add-row-properties
                             start end props))))))))))

(defun testcover-audit-report--insert-list-table (headers rows &optional row-props-fn)
  "Insert ROWS in list format using HEADERS specs.

Each row is inserted as one line with comma-separated
\"Label: value\" pairs.  Percent cells keep their threshold face.
ROW-PROPS-FN, when non-nil, is called with (ROW INDEX) and returns a
plist of navigation properties for that row."
  (when rows
    (cl-loop for row in rows
             for idx from 0
             do (insert (testcover-audit-report--format-list-row headers row))
             do (insert "\n")
             do (when row-props-fn
                  (let ((props (funcall row-props-fn row idx)))
                    (when props
                      (testcover-audit-report--add-row-properties
                       (line-beginning-position) (1- (point)) props)))))))

(defun testcover-audit-report--format-list-row (headers row)
  "Return a list-style line for ROW using HEADERS specs.

Labels come from HEADERS; values from ROW.  Percent cells are
propertized with the threshold face."
  (let ((pairs
         (cl-loop for spec in headers
                  for value in row
                  for type = (nth 1 spec)
                  for label = (car spec)
                  for face = (nth 2 spec)
                  for cell = (testcover-audit-report--cell-string value type)
                  collect
                  (pcase type
                    ('percent
                     (propertize (format "%s: %s" label cell)
                                 'face (testcover-audit-report--face-for-percent value)))
                    (_
                     (let ((s (format "%s: %s" label cell)))
                       (if face (propertize s 'face face) s)))))))
    (mapconcat #'identity pairs ", ")))

(defun testcover-audit-report--insert-overall (stats &optional files-count)
  "Insert the \"Overall\" section from STATS plist.
When FILES-COUNT is non-nil, include a files count line."
  (insert "Overall\n")
  (when files-count
    (insert (format "  Files           %d\n" files-count)))
  (insert (format "  Total forms     %d\n" (plist-get stats :total)))
  (insert (format "  Covered         %d\n" (plist-get stats :covered)))
  (insert (format "  1value          %d\n" (plist-get stats :onevalue)))
  (insert (format "  Uncovered       %d\n" (plist-get stats :uncovered)))
  (insert "  Coverage        ")
  (insert (propertize (format "%d%%" (plist-get stats :percent))
                      'face (testcover-audit-report--face-for-percent
                             (plist-get stats :percent))))
  (insert "\n"))

(defmacro testcover-audit-report--in-report-buffer (buffer-name header &rest body)
  "Run BODY in BUFFER-NAME after erasing it, then display the buffer.
The resulting buffer is made read-only, uses
`testcover-audit-report--navigation-map' as its local keymap, and
HEADER is shown as its header line when non-nil."
  (declare (indent 2))
  `(with-current-buffer (get-buffer-create ,buffer-name)
     (let ((inhibit-read-only t))
       (erase-buffer)
       ,@body)
     (setq buffer-read-only t)
     (setq header-line-format ,header)
     (use-local-map testcover-audit-report--navigation-map)
     (goto-char (point-min))
     (display-buffer (current-buffer))))

(defun testcover-audit-report--message-no-data (file)
  "Message the standard no-coverage warning for FILE."
  (message "No coverage data for %s.\nRun `testcover-start', run your tests, and keep the buffer open."
           (or file "(buffer)")))

;;; Data access

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

(defun testcover-audit-report--function-stats-for-file (file)
  "Return per-function coverage stats for FILE.

Prefer live testcover data from the visiting buffer; fall back to the
`testcover-audit--loaded-files' snapshot.  Return nil when no data is
available."
  (and file
       (or (testcover-audit-scan--buffer-function-stats file)
           (testcover-audit-core--function-stats
            (file-truename (expand-file-name file))))))

(defun testcover-audit-report--collected-file-stats (entries)
  "Return ((FNAME FILEPATH STATS) ...) for ENTRIES with usable STATS."
  (delq nil
        (mapcar
         (lambda (entry)
           (let* ((fpath (if (stringp entry) entry (car entry)))
                  (key (file-truename (expand-file-name fpath)))
                  (stats (and key (testcover-audit-core--file-stats key))))
             (and stats (list (file-relative-name fpath) fpath stats))))
         entries)))

;;; Table variants

(defun testcover-audit-report--insert-function-table (fn-stats &optional file)
  "Insert a function coverage table for FN-STATS.

When FILE is non-nil, bind each function row to jump to that function's
details in the function report buffer.

FN-STATS is a list of plists with at least :name, :total, :covered,
:onevalue, :uncovered and :percent keys."
  (when fn-stats
    (let ((row-props-fn
           (and file
                (lambda (row _idx)
                  (list :keymap testcover-audit-report--function-stats-keymap
                        :file file
                        :function (car row)
                        :help-echo "RET: show function stats")))))
      (testcover-audit-report--insert-table
       '(("Function" text) ("Total" number) ("Covered" number)
         ("1value" number) ("Uncovered" number) ("Coverage" percent))
       (mapcar (lambda (s)
                 (list (or (plist-get s :name) "<anonymous>")
                       (or (plist-get s :total) 0)
                       (or (plist-get s :covered) 0)
                       (or (plist-get s :onevalue) 0)
                       (or (plist-get s :uncovered) 0)
                       (or (plist-get s :percent) 0)))
               fn-stats)
       row-props-fn))))

(defun testcover-audit-report--insert-line-table (entry)
  "Insert a line coverage table for ENTRY.

ENTRY is (SYMBOL . ((LINE . STATS-PLIST) ...))."
  (let ((line-stats (cdr entry)))
    (insert (propertize (symbol-name (car entry))
                        'face 'font-lock-function-name-face)
            "\n")
    (testcover-audit-report--insert-table
     '(("Line" text font-lock-constant-face)
       ("Total" number)
       ("Covered" number)
       ("1value" number)
       ("Uncovered" number)
       ("Coverage" percent))
     (mapcar (lambda (ls)
               (let ((stats (cdr ls)))
                 (list (number-to-string (car ls))
                       (or (plist-get stats :total) 0)
                       (or (plist-get stats :covered) 0)
                       (or (plist-get stats :onevalue) 0)
                       (or (plist-get stats :uncovered) 0)
                       (testcover-audit-core--percent
                        (+ (or (plist-get stats :covered) 0)
                           (or (plist-get stats :onevalue) 0))
                        (or (plist-get stats :total) 0)))))
             line-stats))
    (insert "\n")))

;;; Report navigation

(defvar testcover-audit-report--file-stats-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'testcover-audit-report--goto-file-stats)
    (define-key map [mouse-2] #'testcover-audit-report--goto-file-stats)
    map)
  "Keymap for rows that jump to a file's detailed report.")

(defvar testcover-audit-report--function-stats-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'testcover-audit-report--goto-function-stats)
    (define-key map [mouse-2] #'testcover-audit-report--goto-function-stats)
    map)
  "Keymap for rows that jump to a function's detailed report.")

(defun testcover-audit-report--add-row-properties (start end props)
  "Add navigation PROPS to report row region START..END.
PROPS is a plist with optional keys `:keymap', `:file', `:function'
and `:help-echo'."
  (let ((keymap (plist-get props :keymap))
        (file (plist-get props :file))
        (function (plist-get props :function))
        (help-echo (plist-get props :help-echo)))
    (when keymap
      (put-text-property start end 'keymap keymap))
    (when file
      (put-text-property start end 'testcover-audit-report-file file))
    (when function
      (put-text-property start end 'testcover-audit-report-function function))
    (put-text-property start end 'mouse-face 'highlight)
    (put-text-property start end 'follow-link t)
    (when help-echo
      (put-text-property start end 'help-echo help-echo))))

(defun testcover-audit-report--goto-file-stats ()
  "Show the detailed report for the file on the current line."
  (interactive)
  (let ((file (get-text-property (point) 'testcover-audit-report-file)))
    (if file
        (testcover-audit-report--show-all-stats file)
      (message "No file association on this line"))))

(defun testcover-audit-report--goto-function-stats ()
  "Show the detailed report for the function on the current line."
  (interactive)
  (let* ((file (get-text-property (point) 'testcover-audit-report-file))
         (function (get-text-property (point) 'testcover-audit-report-function)))
    (if file
        (testcover-audit-report--show-function-stats file function)
      (message "No file association on this line"))))

;;; Commands

(defun testcover-audit-report--show-stats ()
  "Show brief coverage statistics for the current buffer."
  (let* ((file (buffer-file-name))
         (stats (testcover-audit-report--stats-for-file file)))
    (if stats
        (message "Coverage: %d%% (%d/%d)"
                 (plist-get stats :percent)
                 (plist-get stats :covered)
                 (plist-get stats :total))
      (testcover-audit-report--message-no-data file))))

(defun testcover-audit-report--show-all-stats (&optional file)
  "Show detailed coverage report in a dedicated buffer for FILE.
When FILE is nil, use the current buffer."
  (let* ((file (or file (buffer-file-name)))
         (stats (testcover-audit-report--stats-for-file file)))
    (if (null stats)
        (testcover-audit-report--message-no-data file)
      (testcover-audit-report--in-report-buffer
          "*Testcover Audit Report*"
          "j/n down, k/p up | RET on a function row: show that function's stats"
        (insert "Testcover Audit Report\n\n")
        (insert (format "File: %s\n\n" (or file "(none)")))
        (testcover-audit-report--insert-overall stats)
        (let ((fn-stats (testcover-audit-report--function-stats-for-file file)))
          (when fn-stats
            (insert "\nFunction-level breakdown\n")
            (testcover-audit-report--insert-function-table fn-stats file)))))))

(defun testcover-audit-report--show-function-stats (&optional file function)
  "Show per-function coverage report for FILE.
When FILE is nil, use the current buffer.  When FUNCTION is non-nil,
move point to that function's section after rendering.

When the current buffer has live testcover position data, show a
line-by-line breakdown for each function.  Otherwise fall back to a
summary table per function."
  (let* ((file (or file (buffer-file-name)))
         (line-entries (and file
                            (testcover-audit-scan--buffer-function-line-stats
                             file)))
         (rows (unless line-entries
                 (testcover-audit-report--function-stats-for-file file))))
    (cond
     ((or line-entries rows)
      (testcover-audit-report--in-report-buffer
          "*Testcover Function Report*"
          "j/n down, k/p up"
        (insert (propertize "Testcover Function Report\n" 'face 'bold))
        (insert (format "File: %s\n\n" (or file "(none)")))
        (if line-entries
            (dolist (entry line-entries)
              (testcover-audit-report--insert-line-table entry))
          (testcover-audit-report--insert-function-table rows)))
      (when function
        (with-current-buffer "*Testcover Function Report*"
          (let ((name (if (symbolp function)
                          (symbol-name function)
                        function)))
            (goto-char (point-min))
            (when (re-search-forward
                   (concat "^" (regexp-quote name) "\\(?:[ \t]\\|$\\)")
                   nil t)
              (beginning-of-line))))))
     (t
      (testcover-audit-report--message-no-data file)))))

(defun testcover-audit-report--batch-report ()
  "Show a detailed coverage report for all instrumented files."
  (let* ((entries (cl-remove-if #'null testcover-audit--loaded-files))
         (collected (testcover-audit-report--collected-file-stats entries))
         (stats (testcover-audit-core--all-files-stats)))
    (if (null collected)
        (message "No coverage data collected.\nRun `testcover-start', run your tests, then `testcover-audit-scan-directory'.")
      (testcover-audit-report--in-report-buffer
          "*Testcover Batch Report*"
          "j/n down, k/p up | RET on file row: file stats; on function row: function stats"
        (insert "Testcover Audit Batch Report\n\n")
        (testcover-audit-report--insert-overall stats (length entries))
        (insert "\nPer-file breakdown\n")
        (testcover-audit-report--insert-table
         '(("File" text) ("Total" number) ("Covered" number)
           ("1value" number) ("Uncovered" number) ("Coverage" percent))
         (mapcar (lambda (item)
                   (let ((fstats (nth 2 item)))
                     (list (nth 0 item)
                           (plist-get fstats :total)
                           (plist-get fstats :covered)
                           (plist-get fstats :onevalue)
                           (plist-get fstats :uncovered)
                           (plist-get fstats :percent))))
                 collected)
         (lambda (_row idx)
           (let* ((item (nth idx collected))
                  (fpath (nth 1 item)))
             (list :keymap testcover-audit-report--file-stats-keymap
                   :file fpath
                   :help-echo "RET: show file stats"))))
        (let* ((threshold testcover-audit-low-coverage-threshold)
               (func-rows
               (cl-loop for item in collected
                        for key = (file-truename (expand-file-name (nth 1 item)))
                        for funcs = (or (testcover-audit-core--function-stats key) '())
                        append (cl-loop for s in funcs
                                        when (< (or (plist-get s :percent) 0) threshold)
                                        collect (list (nth 0 item)
                                                      (or (plist-get s :name) "<anonymous>")
                                                      (or (plist-get s :total) 0)
                                                      (or (plist-get s :covered) 0)
                                                      (or (plist-get s :onevalue) 0)
                                                      (or (plist-get s :uncovered) 0)
                                                      (or (plist-get s :percent) 0))))))
          (setq func-rows
                (sort func-rows
                      (lambda (a b)
                        (or (< (nth 6 a) (nth 6 b))
                            (and (= (nth 6 a) (nth 6 b))
                                 (string< (car a) (car b)))))))
          (when func-rows
            (insert "\nFunction-level breakdown\n")
            (let ((rel-to-fpath
                   (mapcar (lambda (item)
                             (cons (nth 0 item) (nth 1 item)))
                           collected)))
              (testcover-audit-report--insert-table
               '(("File" text) ("Function" text)
                 ("Total" number) ("Covered" number)
                 ("1value" number) ("Uncovered" number)
                 ("Coverage" percent))
               func-rows
               (lambda (row _idx)
                 (let ((fpath (cdr (assoc (car row) rel-to-fpath))))
                   (when fpath
                     (list :keymap testcover-audit-report--function-stats-keymap
                           :file fpath
                           :function (nth 1 row)
                           :help-echo "RET: show function stats"))))))))))))

(defun testcover-audit-report--project-report ()
  "Collect and display existing testcover data for the current project root.

Source files must already have been instrumented and tests must already
have run.  Use `testcover-audit-instrument-directory' before running tests."
  (let ((root (or (locate-dominating-file default-directory ".git")
                  default-directory)))
    (testcover-audit-scan--scan-directory root)
    (testcover-audit-report--batch-report)))

(provide 'testcover-audit-report)
;;; testcover-audit-report.el ends here
