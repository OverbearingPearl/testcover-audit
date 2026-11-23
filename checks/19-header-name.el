;;; 19-header-name.el --- the header line names the file -*- lexical-binding: t; -*-

;;; Commentary:

;; The first line of a module is its header, and it names the file it is in:
;;
;;   ;;; foo.el --- what it is  -*- lexical-binding: t; -*-
;;
;; Nothing else checks that name.  `module-name' checks the `provide', and
;; checkdoc checks the shape of the line; a file copied from another and
;; renamed keeps a header that says the old name, which reads as a lie and
;; costs a reader a minute every time.

;;; Code:

(p/defcheck header-name
  "The first line names the file it is in."
  (let* ((base (file-name-base file))
         (first (with-temp-buffer
                  (insert-file-contents file)
                  (goto-char (point-min))
                  (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))))
         (named (and (string-match "\\`;;;[ \t]+\\([^ \t]+\\)\\.el[ \t]+---" first)
                     (match-string 1 first))))
    (cond
     ((null named)
      (p/add-error check file 1
                   "first line should be `;;; <file>.el --- what it is'"))
     ((not (string= named base))
      (p/add-error check file 1
                   (format "header names %s.el but this file is %s.el"
                           named base))))))
