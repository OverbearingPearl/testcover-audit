;;; testcover-audit-scan.el --- Directory scanning and instrumentation. -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: DeepSeek:deepseek-v4-flash, GLM:glm-5.3-flash, Laguna:laguna-s-2.1
;; URL: https://github.com/OverbearingPearl/testcover-audit
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Recursively scan Emacs Lisp files and collect coverage data from
;; testcover-instrumented definitions.

;;; Code:

(require 'testcover-audit-options)
(require 'testcover-audit-core)
(require 'edebug)
(require 'cl-lib)
(require 'seq)

;; `testcover-audit-core--loaded-files' is the single source of truth
;; for collected coverage data; no local redefinition here.

(defun testcover-audit-scan--coverage-vector-p (vec)
  "Return non-nil if VEC is a non-empty testcover coverage vector.

Testcover stores either state symbols, an arbitrary observed result value,
or a `(noreturn . INDEX)' marker in each slot."
  (and (vectorp vec)
       (> (length vec) 0)))

(defun testcover-audit-scan--definition-coverage (symbol)
  "Return SYMBOL's testcover coverage vector, or nil when absent."
  (let ((coverage (get symbol 'edebug-coverage)))
    (and (eq (get symbol 'edebug-behavior) 'testcover)
         (testcover-audit-scan--coverage-vector-p coverage)
         coverage)))

(defun testcover-audit-scan--buffer-covered-definitions (buffer)
  "Return `(SYMBOL . VECTOR)' entries discovered in BUFFER."
  (with-current-buffer buffer
    (let (entries)
      (dolist (form-data edebug-form-data)
        (let ((symbol (edebug--form-data-name form-data)))
          (when symbol
            (let ((coverage (testcover-audit-scan--definition-coverage symbol)))
              (when coverage
                (push (cons symbol coverage) entries))))))
      (nreverse entries))))

(defun testcover-audit-scan--buffer-function-stats (file)
  "Return per-function coverage stats for FILE from its visiting buffer.

Reads live testcover data from the buffer visiting FILE without
touching `testcover-audit-core--loaded-files'.  Return nil when FILE has no
visiting buffer or no testcover-instrumented definitions."
  (let* ((key (file-truename (expand-file-name file)))
         (buf (find-buffer-visiting key)))
    (when buf
      (let ((entries (testcover-audit-scan--buffer-covered-definitions buf)))
        (and entries
             (testcover-audit-core--file-function-stats
              (cons key entries)))))))

(defun testcover-audit-scan--definition-line-stats (symbol coverage baseline)
  "Return per-line stats for SYMBOL's COVERAGE vector relative to BASELINE.

Uses Edebug's stored position data to map each coverage index to a
buffer position, then groups forms by source line.  Current buffer
must contain the instrumented definition.

Return a list of (LINE . STATS-PLIST) sorted by LINE, or nil when
SYMBOL has no usable position data."
  (let* ((edata (get symbol 'edebug))
         (def-mark (car edata))
         (points (nth 2 edata)))
    (when (and (markerp def-mark)
               (marker-buffer def-mark)
               (vectorp points)
               (> (length points) 0))
      (let* ((len (min (length coverage) (length points) (length baseline)))
             (lines (make-hash-table :test 'eql)))
        (dotimes (i len)
          (let* ((type (testcover-audit-core--delta-type
                        (aref baseline i) (aref coverage i)))
                 (stats (gethash (line-number-at-pos
                                  (+ def-mark (aref points i)))
                                 lines
                                 (list :total 0 :covered 0
                                       :onevalue 0 :uncovered 0))))
            (unless (eq type 'ignored)
              (cl-incf (plist-get stats :total))
              (cl-case type
                (covered   (cl-incf (plist-get stats :covered)))
                (onevalue  (cl-incf (plist-get stats :onevalue)))
                (uncovered (cl-incf (plist-get stats :uncovered)))))
            (puthash (line-number-at-pos (+ def-mark (aref points i)))
                     stats lines)))
        (let (result)
          (maphash (lambda (line stats)
                     (push (cons line stats) result))
                   lines)
          (sort result (lambda (a b) (< (car a) (car b)))))))))

(defun testcover-audit-scan--buffer-function-line-stats (file)
  "Return per-function per-line coverage for FILE from its visiting buffer.

Return a list of (SYMBOL . ((LINE . STATS-PLIST) ...)) entries, or nil
when FILE has no visiting buffer or no usable position data."
  (let* ((key (file-truename (expand-file-name file)))
         (buf (find-buffer-visiting key)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let* ((entries (testcover-audit-scan--buffer-covered-definitions buf))
               (line-entries
                (delq nil
                      (mapcar (lambda (entry)
                                (let* ((sym (car entry))
                                       (baseline
                                        (gethash sym testcover-audit-core--initial-vectors))
                                       (line-stats
                                        (and baseline
                                             (testcover-audit-scan--definition-line-stats
                                              sym (cdr entry) baseline))))
                                  (and line-stats
                                       (cons sym line-stats))))
                              entries))))
          (and line-entries line-entries))))))

(defun testcover-audit-scan--buffer-stats (file)
  "Return live coverage stats for FILE from its visiting buffer.

Unlike `testcover-audit-scan--scan-directory', this reads testcover
coverage directly from the buffer visiting FILE and does not touch
`testcover-audit-core--loaded-files'.

Return nil when FILE has no visiting buffer or no testcover-instrumented
definitions."
  (let ((fn-stats (testcover-audit-scan--buffer-function-stats file)))
    (and fn-stats (testcover-audit-core--aggregate fn-stats))))

(defun testcover-audit-scan--source-files (directory)
  "Return auditable source files under DIRECTORY."
  (let ((files (directory-files-recursively directory "\\.el$")))
    (cl-remove-if
     (lambda (file)
       (or (seq-some (lambda (rx)
                       (string-match-p rx (file-name-nondirectory file)))
                     testcover-audit-exclude-files)
           (and testcover-audit-test-file-regexp
                (string-match-p testcover-audit-test-file-regexp file))))
     (mapcar (lambda (file)
               (file-truename (expand-file-name file)))
             files))))

(defun testcover-audit-scan--instrument-directory (directory)
  "Instrument source files under DIRECTORY with `testcover-start'.

Test files matching `testcover-audit-test-file-regexp' and files matching
`testcover-audit-exclude-files' are skipped.  This command intentionally
does not load or run tests."
  (require 'testcover)
  (let* ((files (testcover-audit-scan--source-files directory))
         (source-dirs
          (delete-dups
           (mapcar (lambda (file)
                     (directory-file-name (file-name-directory file)))
                   files)))
         ;; `testcover-start' evaluates the file with `eval-buffer'.
         ;; Add the files' directories to `load-path' so that `require'
         ;; forms inside them can be resolved during that evaluation.
         (load-path (append source-dirs load-path)))
    (dolist (file files)
      (testcover-start file))
    (message "Instrumented %d source files under %s."
             (length files) directory)
    files))

(defun testcover-audit-scan--scan-directory (directory)
  "Recursively scan DIRECTORY and collect coverage data.

The command does NOT instrument files.  It gathers coverage vectors from
testcover-instrumented definitions associated with buffers visiting .el files
under DIRECTORY and having already been instrumented with `testcover-start'
running the relevant tests.  Files that are not open or not instrumented
are skipped; use `testcover-audit-core--loaded-files' to see what was found."
  (let ((files (testcover-audit-scan--source-files directory))
        (not-open 0)
        (dead-buffer 0)
        (no-instrumented 0)
        (no-baseline 0))
    (setq testcover-audit-core--loaded-files nil)
    (dolist (file files)
      (let ((buf (find-buffer-visiting file)))
        (cond
         ((null buf)
          (cl-incf not-open))
         ((not (buffer-live-p buf))
          (cl-incf dead-buffer))
         (t
          (with-current-buffer buf
            (let* ((entries (testcover-audit-scan--buffer-covered-definitions buf))
                   (baselined
                    (cl-remove-if-not
                     (lambda (entry)
                       (gethash (car entry) testcover-audit-core--initial-vectors))
                     entries)))
              (cond
               (baselined
                (push (cons file baselined) testcover-audit-core--loaded-files))
               (entries
                (cl-incf no-baseline))
               (t
                (cl-incf no-instrumented)))))))))
    (message "Scanned %d files, collected coverage from %d."
             (length files) (length testcover-audit-core--loaded-files))
    (when (< (length testcover-audit-core--loaded-files) (length files))
      (message
       "Skipped %d files: %d not open, %d with dead buffers, %d without testcover-instrumented definitions, %d without testcover-audit baseline."
       (- (length files) (length testcover-audit-core--loaded-files))
       not-open dead-buffer no-instrumented no-baseline))))

(provide 'testcover-audit-scan)
;;; testcover-audit-scan.el ends here
