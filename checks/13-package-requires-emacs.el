;;; 13-package-requires-emacs.el --- emacs floor declaration -*- lexical-binding: t; -*-

;;; Commentary:

;; The main file's Package-Requires emacs dependency must be at least the
;; Emacs the suite runs on. A package that promises an older one is claiming
;; support for a version nothing here has ever linted.

;;; Code:

(p/defcheck-global package-requires-emacs :scope "the main file"
  "The declared emacs requirement must meet the configured minimum."
  (let* ((main (p/main-file))
         (min-v (car (p/config-value :emacs-versions)))
         (declared (p/package-requires-emacs-version main)))
    (cond
     ((null declared)
      (p/add-error check main nil
                   (format "missing Package-Requires emacs dependency (the suite runs on %s)"
                           min-v)))
     ((version< declared min-v)
      (p/add-error check main nil
                   (format "Package-Requires emacs %s is below the %s the suite runs on"
                           declared min-v))))))
