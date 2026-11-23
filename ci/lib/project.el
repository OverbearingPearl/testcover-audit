;;; project.el --- Repository identity and file discovery -*- lexical-binding: t; -*-

;;; Commentary:

;; Everything here derives the package name, main file, and per-file
;; module class from the repository layout.  No project-specific names
;; are hard-coded: the package is discovered, not configured.
;;
;;   main      the single .el file at the repository root
;;   business  any .el under the submodule directory
;;   test      any .el under the test directory
;;   tooling   any .el under the tooling directory (the check suite itself)

;;; Code:

(require 'seq)

(defvar p/repo-root-cache nil
  "Cached repository root directory.")

(defun p/git-toplevel ()
  "Return the repository root via git, or nil outside a repository."
  (with-temp-buffer
    (when (zerop (call-process "git" nil t nil "rev-parse" "--show-toplevel"))
      (string-trim (buffer-string)))))

(defun p/repo-root ()
  "Return the repository root directory, cached."
  (or p/repo-root-cache
      (setq p/repo-root-cache
            (or (p/git-toplevel)
                (file-name-as-directory (expand-file-name default-directory))))))

(defun p/main-file ()
  "Discover and return the package main file path.
The layout requires exactly one .el file at the repository root; signal
an error otherwise.  The file name is not required to match the
repository name."
  (let ((candidates (p/dir-el-files (p/repo-root))))
    (pcase (length candidates)
      (1 (car candidates))
      (0 (error "No .el main file at the repository root; the package entry point belongs there"))
      (_ (error "Expected exactly one .el at the repository root, found: %s"
                (mapconcat #'file-name-nondirectory candidates ", "))))))

(defun p/package-name ()
  "Return the package name derived from the main file."
  (file-name-base (p/main-file)))

(defun p/package-version ()
  "Return the version declared in the main file's Version header."
  (let ((main (p/main-file)))
    (with-temp-buffer
      (insert-file-contents main)
      (goto-char (point-min))
      (when (re-search-forward "^;; Version:[ \t]*\\(.+\\)$" nil t)
        (string-trim (match-string 1))))))

(defun p/submodule-dir ()
  "Return the absolute business submodule directory."
  (expand-file-name (p/config-value :submodule-dir) (p/repo-root)))

(defun p/test-dir ()
  "Return the absolute test module directory."
  (expand-file-name (p/config-value :test-dir) (p/repo-root)))

(defun p/tooling-dir ()
  "Return the absolute tooling directory."
  (expand-file-name (p/config-value :tooling-dir) (p/repo-root)))

(defun p/vendor-dir ()
  "Return the absolute vendored-code directory."
  (expand-file-name (or (p/config-value :vendor-dir) "vendor") (p/repo-root)))

(defun p/vendor-load-path ()
  "Return the directories a vendored package may be loaded from.
The vendor directory itself, plus one level down: a vendored package usually
keeps its own name as a directory, and `require' looks in the directory that
holds the file rather than in the one above it."
  (let ((dir (p/vendor-dir)))
    (append
     (and (file-directory-p dir) (list dir))
     (when (file-directory-p dir)
       (sort (seq-filter #'file-directory-p
                         (directory-files dir t "\`[^.]" t))
             #'string<)))))

(defun p/dir-el-files (dir)
  "Return the sorted .el files directly inside DIR, or nil."
  (when (file-directory-p dir)
    (seq-filter #'file-regular-p (directory-files dir t "\\.el\\'" t))))

(defun p/recursive-el-files (dir)
  "Return the sorted .el files under DIR, recursively."
  (when (file-directory-p dir)
    (sort (seq-filter (lambda (f)
                        (and (file-regular-p f)
                             (string-suffix-p ".el" f)))
                      (directory-files-recursively dir "\\.el\\'"))
          #'string<)))

(defun p/discover-files ()
  "Return the ordered list of .el files to check.
Order: business modules, the root main file, test modules, then the
tooling in the check suite itself."
  (append (sort (p/dir-el-files (p/submodule-dir)) #'string<)
          (list (p/main-file))
          (sort (p/dir-el-files (p/test-dir)) #'string<)
          (p/recursive-el-files (p/tooling-dir))
          ;; Vendored packages keep their own layout, so this one is
          ;; recursive: `vendor/name/name.el' is the normal shape.
          (p/recursive-el-files (p/vendor-dir))))

(defun p/module-class (file)
  "Return the module class of FILE.
Classes are `main', `business', `test' and `tooling'; nil when FILE is
not checked at all.  The directory decides the class, file names play no
part."
  (cond
   ((and (file-equal-p file (p/main-file)) 'main))
   ((and (file-in-directory-p file (p/test-dir)) 'test))
   ((and (file-in-directory-p file (p/submodule-dir)) 'business))
   ((and (file-in-directory-p file (p/tooling-dir)) 'tooling)
    'tooling)
   ((and (file-in-directory-p file (p/vendor-dir)) 'vendor)
    'vendor)
   (t nil)))

(defun p/test-file-p (file)
  "Return non-nil when FILE is a test module."
  (eq (p/module-class file) 'test))

(defun p/file-top-level-requires (file)
  "Return feature symbols required at top level in FILE.
Accepts both (require 'feature) and (require feature)."
  (let ((requires '()))
    (dolist (pair (p/top-level-forms file))
      (let ((form (car pair)))
        (when (and (consp form) (eq (car form) 'require))
          (let ((arg (cadr form)))
            (when (and (consp arg) (eq (car arg) 'quote))
              (setq arg (cadr arg)))
            (when (symbolp arg)
              (push arg requires))))))
    (nreverse requires)))

(defun p/tracked-files ()
  "Return repository-relative paths of tracked and untracked files.
Ignored files and paths that no longer exist in the worktree are
excluded.  Return nil outside a git repository."
  (with-temp-buffer
    (when (zerop (call-process "git" nil t nil "ls-files" "-z"
                               "--cached" "--others" "--exclude-standard"))
      (let ((root (p/repo-root)))
        (sort
         (seq-filter (lambda (rel)
                       (file-regular-p (expand-file-name rel root)))
                     (seq-remove #'string-empty-p
                                 (split-string (buffer-string) "\0" t)))
         #'string<)))))
