;;; testcover-audit-scan.el --- Directory scanning and instrumentation. -*- lexical-binding: t; -*-

;; Copyright (C) 2026 OverbearingPearl
;; Author: OverbearingPearl <OverbearingPearl@outlook.com>
;; Assisted-by: Deepseek:deepseek-v4-flash
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
(require 'project)

(defvar testcover-audit--loaded-files nil
  "Alist of (file . function-coverage-entries) pairs collected by `testcover-audit-scan-directory'.")

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

;;;###autoload
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
  (let ((files (testcover-audit-scan--source-files directory)))
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
are skipped; use `testcover-audit--loaded-files' to see what was found."
  (let ((files (testcover-audit-scan--source-files directory))
        (not-open 0)
        (dead-buffer 0)
        (no-instrumented 0))
    (setq testcover-audit--loaded-files nil)
    (dolist (file files)
      (let ((buf (find-buffer-visiting file)))
        (cond
         ((null buf)
          (cl-incf not-open))
         ((not (buffer-live-p buf))
          (cl-incf dead-buffer))
         (t
          (with-current-buffer buf
            (let ((entries (testcover-audit-scan--buffer-covered-definitions buf)))
              (if entries
                  (push (cons file entries) testcover-audit--loaded-files)
                (cl-incf no-instrumented))))))))
    (message "Scanned %d files, collected coverage from %d."
             (length files) (length testcover-audit--loaded-files))
    (when (< (length testcover-audit--loaded-files) (length files))
      (message
       "Skipped %d files: %d not open, %d with dead buffers, %d without testcover-instrumented definitions."
       (- (length files) (length testcover-audit--loaded-files))
       not-open dead-buffer no-instrumented))))

;;;###autoload
(defun testcover-audit-scan--project-report ()
  "Collect and display existing testcover data for the current project root.

Source files must already have been instrumented and tests must already
have run.  Use `testcover-audit-instrument-directory' before running tests."
  (let* ((proj (project-current))
         (root (if proj (project-root proj) default-directory)))
    (testcover-audit-scan--scan-directory root)
    (testcover-audit-report--batch-report)))

(defun testcover-audit-scan--dependency-order (files)
  "Order FILES by dependency (require) relationships.

For the current implementation a simple alphabetical sort is used,
which is sufficient for most small projects."
  (sort files #'string<))

(provide 'testcover-audit-scan)
;;; testcover-audit-scan.el ends here
