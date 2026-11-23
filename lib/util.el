;;; util.el --- Shared text helpers for the check suite  -*- lexical-binding: t; -*-

;;; Commentary:

;; Small predicates shared by several checks.

;;; Code:

(require 'lisp-mode)

(defconst p/blank-line-rx
  (rx line-start (* (any blank)) line-end)
  "Regexp matching an empty or blank-only line.")

(defconst p/h3-comment-rx
  (rx line-start (* (any blank)) ";;;")
  "Regexp matching a level-three (`;;;') comment line.")

(defconst p/autoload-cookie-rx
  (rx line-start (* (any blank)) ";;;###")
  "Regexp matching an autoload cookie line.")

(defconst p/keyword-sep-rx
  (rx (+ (any space ",;")))
  "Regexp matching separators in a `Keywords:' meta line.")

(defun p/blank-line-p (s)
  "Return non-nil if S is empty or contains only blanks."
  (string-match-p p/blank-line-rx s))

(defun p/h3-comment-p (s)
  "Return non-nil if S is a `;;;' comment but not an autoload cookie."
  (and (string-match-p p/h3-comment-rx s)
       (not (string-match-p p/autoload-cookie-rx s))))

(defun p/meta-line-p (line prefix &optional allow-indent)
  "Return non-nil if LINE starts with PREFIX.
Leading blanks are allowed when ALLOW-INDENT is non-nil."
  (string-prefix-p prefix
                   (if allow-indent (string-trim-left line) line)))

(defun p/file-lines (file)
  "Return FILE contents as a list of lines, trailing newline dropped."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((lines (split-string (buffer-string) "\n")))
      (if (and lines (string-empty-p (car (last lines))))
          (butlast lines)
        lines))))

(defun p/top-level-forms (file)
  "Return a list of (FORM . LINE) for each top-level form in FILE.
LINE is the line the form starts on.  Signal an error when FILE cannot
be read as Emacs Lisp."
  (let ((forms '()))
    (with-temp-buffer
      (insert-file-contents file)
      (with-syntax-table emacs-lisp-mode-syntax-table
        (goto-char (point-min))
        (condition-case err
            (while (progn (forward-comment (point-max))
                          (not (eobp)))
              (let ((line (line-number-at-pos)))
                (push (cons (read (current-buffer)) line) forms)))
          (end-of-file nil)
          (error (error "Failed to read %s: %S"
                        (file-relative-name file default-directory) err)))))
    (nreverse forms)))

(defun p/package-requires-emacs-version (file)
  "Return the emacs version declared in FILE's Package-Requires, or nil."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (when (re-search-forward
           "^;; Package-Requires:.*emacs[ \t\n]*\"\\([^\"]+\\)\"" nil t)
      (match-string 1))))
