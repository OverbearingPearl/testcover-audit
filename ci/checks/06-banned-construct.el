;;; 06-banned-construct.el --- forbidden constructs -*- lexical-binding: t; -*-

;;; Commentary:

;; Flags constructs listed in the policy's :banned table, each with a
;; suggested replacement.  Occurrences inside strings are ignored, so the
;; policy itself can name the forbidden text; symbol patterns are also
;; ignored inside comments.

;;; Code:

(defun p/banned-match-matters-p (state needle)
  "Return non-nil when a match with syntax STATE matters for NEEDLE.
Comment directives are reported where they appear as comments; symbol
patterns are reported where they appear as code."
  (let ((in-string (nth 3 state))
        (in-comment (nth 4 state)))
    (cond
     (in-string nil)
     ((string-prefix-p ";;" needle) in-comment)
     (t (not in-comment)))))

(p/defcheck banned-construct
  "Forbid configured constructs and suggest replacements."
  (with-temp-buffer
    (insert-file-contents file)
    (set-syntax-table emacs-lisp-mode-syntax-table)
    (dolist (entry (p/config-value :banned))
      (let ((needle (car entry))
            (instead (cdr entry))
            (display (replace-regexp-in-string "\\\\_<\\|\\\\_>" "" (car entry))))
        (goto-char (point-min))
        (while (re-search-forward needle nil t)
          (let* ((pos (match-beginning 0))
                 (state (syntax-ppss (min (1+ pos) (point-max)))))
            (when (p/banned-match-matters-p state needle)
              (p/add-error check file (line-number-at-pos pos)
                           (format "banned construct `%s'; %s"
                                   display instead)))))))))
