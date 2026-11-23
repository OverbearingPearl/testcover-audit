;;; 01-package-lint.el --- package-lint on published modules -*- lexical-binding: t; -*-

;;; Commentary:

;; Runs package-lint-current-buffer with the main file pinned.
;;
;; Test modules are excluded by class: package-lint models a published
;; package and its prefix rule would reject the plain names that test
;; modules are allowed to use.  The tooling under ci/ is excluded for the
;; same reason.

;;; Code:

(p/defcheck package-lint :classes (main business)
  "package-lint-current-buffer with the main file pinned."
  (let ((package-lint-main-file (p/main-file)))
    (when (get-buffer "*Package-Lint*")
      (kill-buffer "*Package-Lint*"))
    (p/with-file-buffer
     file
     (lambda ()
       (package-lint-current-buffer)))
    (let ((pl (string-trim
               (or (and (get-buffer "*Package-Lint*")
                        (with-current-buffer "*Package-Lint*"
                          (buffer-string)))
                   ""))))
      (unless (or (string-empty-p pl)
                  (string= pl "No issues found."))
        (dolist (line (split-string pl "\n" t))
          (p/add-error check file nil line))))))
