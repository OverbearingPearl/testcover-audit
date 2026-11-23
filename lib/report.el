;;; report.el --- Result collection, formatting and annotations -*- lexical-binding: t; -*-

;;; Commentary:

;; Checks report issues through `p/add-error'.  Human output is one
;; "file:line: [check] message" per line; under GitHub Actions the same
;; issues are also emitted as workflow annotations.

;;; Code:

(defvar p/errors '()
  "Structured issue list; each entry is (check file line message).")

(defun p/reset-errors ()
  "Clear the issue list."
  (setq p/errors '()))

(defun p/add-error (check file line message)
  "Record an issue for CHECK in FILE at LINE (or nil) with MESSAGE."
  (push (list check file line message) p/errors))

(defun p/with-file-buffer (file fn)
  "Run FN in a buffer visiting FILE, then kill the buffer."
  (let ((buf (find-file-noselect file t)))
    (unwind-protect
        (with-current-buffer buf
          (funcall fn))
      (kill-buffer buf))))

(defun p/format-error (err)
  "Format a single issue entry."
  (pcase-let ((`(,check ,file ,line ,message) err))
    (format "%s%s: [%s] %s"
            (file-relative-name file (p/repo-root))
            (if line (format ":%d" line) "")
            check
            message)))

(defun p/print-errors ()
  "Print all recorded issues to standard output."
  (dolist (e (nreverse p/errors))
    (princ (concat (p/format-error e) "\n"))))

(defun p/emit-annotations ()
  "Emit GitHub workflow annotations for recorded issues."
  (when (getenv "GITHUB_ACTIONS")
    (dolist (e (nreverse p/errors))
      (pcase-let ((`(,check ,file ,line ,message) e))
        (princ (format "::error file=%s,line=%d,title=%s::%s\n"
                       (file-relative-name file (p/repo-root))
                       (or line 1)
                       check
                       message))))))
