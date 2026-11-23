;;; 04-heading-comment.el --- heading comment style -*- lexical-binding: t; -*-

;;; Commentary:

;; `;;;' heading comments (except autoload cookies) must be surrounded
;; by blank lines.

;;; Code:

(p/defcheck heading-comment
  "`;;;' headings (except autoload cookies) need surrounding blank lines."
  (let ((lines (p/file-lines file)))
    (dotimes (i (length lines))
      (when (p/h3-comment-p (nth i lines))
        (let ((prev-blank (or (= i 0)
                              (p/blank-line-p (nth (1- i) lines))))
              (next-blank (or (= i (1- (length lines)))
                              (p/blank-line-p (nth (1+ i) lines)))))
          (unless (and prev-blank next-blank)
            (p/add-error check file (1+ i)
                         "heading comment must be surrounded by blank lines")))))))
