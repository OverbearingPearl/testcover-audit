;;; deps.el --- Ensure required packages are available -*- lexical-binding: t; -*-

;;; Commentary:

;; The suite has two third-party dependencies: package-lint for the checks and
;; testcover-audit for `make coverage'.  Each caller asks for the one it needs,
;; so a lint run does not download the coverage tools and a coverage run does
;; not download package-lint.  The user's existing ELPA directory is preferred;
;; otherwise the package goes into a project-local cache (needs network exactly
;; once, then fully offline).
;;
;; A project's tests may also need a package of their own, named in
;; `:test-packages'.  Those are test-only, so they are taken from the project
;; cache even when the user has one: a stale global copy must not decide what
;; the suite compiles against, and an old macro can fail the lint on a newer
;; Emacs while the CI's fresh copy passes.

;;; Code:

(require 'package)
(require 'seq)

(defconst p/suite-dependencies '(package-lint testcover-audit)
  "Packages the suite installs for itself.
`package-lint' runs the checks and `testcover-audit' measures coverage.  A
project that is one of them cannot keep its name out of `ci/': the tree has
to name the dependency, so `project-neutral' does not run for it.")

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

(defun p/ensure-test-packages ()
  "Install and load the packages the project lists in :test-packages.
Each name is both the package and the feature to require.  They come from
the project cache even when `~/.emacs.d/elpa' has a copy: a test dependency
that decided what the suite compiles against would be whichever version the
machine happened to install first.  Nothing to do when the list is nil."
  (let ((packages (p/config-value :test-packages)))
    (when packages
      (setq package-user-dir
            (or (getenv "P_ELPA_DIR")
                (expand-file-name ".cache/elpa" (p/repo-root))))
      (setq package-archives
            '(("gnu" . "https://elpa.gnu.org/packages/")
              ("melpa" . "https://melpa.org/packages/")))
      (setq package-check-signature nil)
      (unless (file-directory-p package-user-dir)
        (make-directory package-user-dir t))
      (package-initialize)
      ;; `package-initialize' activates the cache's packages, but a copy the
      ;; user's ELPA put on `load-path' earlier stays ahead of it.  Put the
      ;; cache first, then install whatever is still missing.
      (setq load-path
            (append (seq-filter #'file-directory-p
                                (directory-files package-user-dir t "\\`[^.]"))
                    load-path))
      (dolist (package packages)
        (unless (package-installed-p package)
          (package-refresh-contents)
          (package-install package))
        (require package)))))

(provide 'deps)

;;; deps.el ends here
