;;; 15-text-hygiene.el --- hygiene for every text file -*- lexical-binding: t; -*-

;;; Commentary:

;; Every file git knows about, tracked or untracked, that is not binary,
;; Emacs Lisp included:
;; no trailing whitespace and exactly one final newline.  This is the
;; check that covers files the package checks never look at, such as
;; ci/, .github/, README and .gitignore.
;;
;; The vendor directory is left out.  A vendored file is a copy, not
;; something the project writes, and fixing its whitespace would put it
;; at odds with the release it came from for no gain; `dependency-
;; direction' is the one rule that still reaches it.

;;; Code:

(defun p/binary-file-p (file)
  "Return non-nil if FILE contains a NUL byte."
  (with-temp-buffer
    (insert-file-contents-literally file)
    (search-forward "\0" nil t)))

(defun p/text-hygiene-file (check root rel)
  "Report hygiene issues for REL under ROOT."
  (let ((full (expand-file-name rel root)))
    (when (and (file-regular-p full)
               (not (p/binary-file-p full)))
      (let ((content (with-temp-buffer
                       (insert-file-contents-literally full)
                       (buffer-string))))
        (unless (string-suffix-p "\n" content)
          (p/add-error check full nil "missing final newline"))
        (when (string-suffix-p "\n\n" content)
          (p/add-error check full nil "more than one final newline"))
        (let ((line-num 0))
          (dolist (line (split-string content "\n"))
            (setq line-num (1+ line-num))
            (when (string-match-p "[ \t]+\r?$" line)
              (p/add-error check full line-num "trailing whitespace"))))))))

(p/defcheck-global text-hygiene
  :scope "every tracked or untracked text file outside vendor/"
  "Every tracked or untracked text file outside vendor/: no trailing whitespace, one final newline."
  (let ((root (p/repo-root))
        (vendor (p/vendor-dir)))
    (dolist (rel (p/tracked-files))
      (let ((full (expand-file-name rel root)))
        (unless (and (file-directory-p vendor)
                     (file-in-directory-p full vendor))
          (p/text-hygiene-file check root rel))))))
