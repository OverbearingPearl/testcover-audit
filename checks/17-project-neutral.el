;;; 17-project-neutral.el --- no project names in the copyable parts -*- lexical-binding: t; -*-

;;; Commentary:

;; `ci/' and `.github/' are meant to be copied into another Emacs Lisp
;; package as they are.  The package name showing up there defeats that
;; quietly: the copy lints, the copy runs, and the copy still tells every
;; reader it belongs to somebody else.
;;
;; So the name may not appear in either tree.  It is derived from the main
;; file, never written down here -- which is also why this check has nothing
;; to search for until it runs, and why the check itself is covered by it.

;;; Code:

(require 'seq)

(defconst p/neutral-dirs '("ci" ".github")
  "Directories that must not mention the package name.")

(p/defcheck-global project-neutral :scope "ci/ and .github/"
  "The copyable directories: ci/ and .github/ never name the package."
  (let ((name (p/package-name))
        (root (p/repo-root))
        (pattern nil))
    (setq pattern (concat "\\<" (regexp-quote name) "\\>"))
    (dolist (rel (p/tracked-files))
      (when (seq-some (lambda (dir) (string-prefix-p (concat dir "/") rel))
                      p/neutral-dirs)
        (let ((full (expand-file-name rel root)))
          (when (file-regular-p full)
            (with-temp-buffer
              (insert-file-contents-literally full)
              (goto-char (point-min))
              (let ((line 0))
                (while (not (eobp))
                  (setq line (1+ line))
                  (when (string-match-p
                         pattern
                         (buffer-substring (line-beginning-position)
                                           (line-end-position)))
                    (p/add-error check full line
                                 (format "names the package (%s); the copyable trees must not" name)))
                  (forward-line 1))))))))))
