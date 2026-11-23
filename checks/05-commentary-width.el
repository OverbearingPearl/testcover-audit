;;; 05-commentary-width.el --- Commentary width check -*- lexical-binding: t; -*-

;;; Commentary:

;; Lines inside the `;;; Commentary' block must fit within the configured
;; width.  The block runs from the Commentary heading to the next `;;;'
;; heading; autoload cookies neither start nor end it.  Width is columns as
;; displayed, not characters: a CJK line of 52 characters takes 101 columns,
;; and counting characters would give it twice the budget.

;;; Code:

(p/defcheck commentary-width
  "Commentary lines must fit within the configured width."
  (let ((max (p/config-value :commentary-width))
        (lines (p/file-lines file))
        (in-block nil)
        (line-num 0))
    (dolist (line lines)
      (setq line-num (1+ line-num))
      (cond
       ((string-match-p "\\`;;;[ \t]*Commentary:?[ \t]*\\'" line)
        (setq in-block t))
       ((and in-block (p/h3-comment-p line))
        (setq in-block nil)))
      (when (and in-block (> (string-width line) max))
        (p/add-error check file line-num
                     (format "commentary line wider than %d characters" max))))))
