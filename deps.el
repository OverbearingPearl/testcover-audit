;;; deps.el --- Ensure required packages are available -*- lexical-binding: t; -*-

;;; Commentary:

;; The suite has two third-party dependencies: package-lint for the checks and
;; testcover-audit for `make coverage'.  Each caller asks for the one it needs,
;; so a lint run does not download the coverage tools and a coverage run does
;; not download package-lint.  The user's existing ELPA directory is preferred;
;; otherwise the package goes into a project-local cache (needs network exactly
;; once, then fully offline).

;;; Code:

(require 'package)

(defun p/require-feature (feature)
  "Load FEATURE, returning non-nil on success."
  (condition-case nil
      (progn (require feature) t)
    (error nil)))

(defun p/ensure-package (package feature)
  "Load FEATURE, installing PACKAGE when it is missing.
The user's `~/.emacs.d/elpa' is tried first.  When FEATURE is not there, the
project-local `.cache/elpa' is used instead, so a machine with no ELPA
directory of its own still gets a working run after one download.  P_ELPA_DIR
names a different cache, which is what a CI job wants when it caches a path."
  (unless (p/require-feature feature)
    (let ((package-user-dir (expand-file-name "~/.emacs.d/elpa")))
      (package-initialize))
    (unless (p/require-feature feature)
      (setq package-user-dir
            (or (getenv "P_ELPA_DIR")
                (expand-file-name ".cache/elpa" (p/repo-root))))
      (setq package-archives
            '(("gnu" . "https://elpa.gnu.org/packages/")
              ("melpa" . "https://melpa.org/packages/")))
      (setq package-check-signature nil)
      (package-initialize)
      (unless (p/require-feature feature)
        (package-refresh-contents)
        (package-install package))
      (require feature))))

(provide 'deps)

;;; deps.el ends here
