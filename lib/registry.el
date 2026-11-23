;;; registry.el --- Check registration and runner -*- lexical-binding: t; -*-

;;; Commentary:

;; A check is registered with `p/register-check'.  Per-file checks are
;; called with (file class); global checks are called with the full
;; ordered file list.  `p/main' dispatches on command-line flags:
;;   (no flags)        run every check, exit non-zero on any issue
;;   --list            print the check table
;;   --files           print the files the suite inspects, by class
;;   --explain FILE    print which checks apply to FILE and why

;;; Code:

(defconst p/all-classes '(main business test tooling vendor)
  "Every module class the policy knows about.
A class is here because a module can be of it and because `:profiles' has to
answer for it, not because every check should look at it.  Vendored code is
the case in point: it belongs to a class, and nearly every rule about our own
source does not apply to it.")

(defconst p/default-check-classes '(main business test tooling)
  "Classes a per-file check runs on unless it names its own.
`vendor' is deliberately absent: a vendored file is not ours to restyle, and
a check that wants it says so.")

(defvar p/check-registry '()
  "Ordered list of registered checks: (name doc fn global classes).")

(defun p/register-check (name doc fn global &optional classes)
  "Register a check named NAME with docstring DOC.
FN is called per file (with file and class) unless GLOBAL is non-nil,
in which case it is called once with the full file list.  CLASSES is
either the list of module classes a per-file check runs on, or a short
description of what a global check looks at."
  (setq p/check-registry
        (append p/check-registry
                (list (list name doc fn global
                            (or classes p/default-check-classes))))))

(defmacro p/defcheck (name &rest args)
  "Define a per-file check named NAME.
ARGS is an optional class plist, a docstring, then the body.  The body
runs with `file' and `class' bound, plus `check' naming the check.  The
plist restricts the classes the check runs on; without it the check runs
on every class in `p/all-classes'."
  (declare (indent 1))
  (let (plist
        (doc nil))
    ;; Optional leading plist: consume key/value pairs.
    (while (keywordp (car args))
      (setq plist (append plist (list (pop args) (pop args)))))
    (setq doc (pop args))
    `(p/register-check ',name ,doc
                       (lambda (file class)
                         (when (memq class ',(or (plist-get plist :classes)
                                                 p/default-check-classes))
                           (let ((check ',name))
                             ,@args)))
                       nil
                       ',(plist-get plist :classes))))

(defmacro p/defcheck-global (name &rest args)
  "Define a global check named NAME.
ARGS is an optional plist with :scope (a short description of what the
check looks at), a docstring, then the body.  The body runs with `files'
bound, plus `check' naming the check."
  (declare (indent 1))
  (let (plist
        (doc nil))
    (while (keywordp (car args))
      (setq plist (append plist (list (pop args) (pop args)))))
    (setq doc (pop args))
    `(p/register-check ',name ,doc
                       (lambda (files)
                         (let ((check ',name))
                           ,@args))
                       t
                       ',(plist-get plist :scope))))

(defun p/load-checks (dir)
  "Load every check file in DIR in name order."
  (dolist (f (sort (directory-files dir t "\\.el\\'" t) #'string<))
    (load f nil t)))

(defun p/run-checks-internal ()
  "Run all registered checks; return non-nil when anything failed."
  (add-to-list 'load-path (p/repo-root))
  (add-to-list 'load-path (p/submodule-dir))
  (add-to-list 'load-path (p/test-dir))
  ;; A test may depend on a vendored package; the suite puts it where
  ;; `require' finds it, exactly as it does for the package and the tests.
  (dolist (dir (reverse (p/vendor-load-path)))
    (add-to-list 'load-path dir))
  (let ((files (p/discover-files)))
    (p/reset-errors)
    (dolist (entry p/check-registry)
      (pcase-let ((`(,_name ,_doc ,fn ,global ,_classes) entry))
        (if global
            (funcall fn files)
          (dolist (file files)
            (funcall fn file (p/module-class file))))))
    (p/print-errors)
    (p/emit-annotations)
    (> (length p/errors) 0)))

(defun p/run-checks ()
  "Run all checks, reporting fatal setup errors as a failure."
  (condition-case err
      (p/run-checks-internal)
    (error
     (princ (format "fatal: %s\n" (error-message-string err)))
     t)))

(defun p/print-file-scope ()
  "Print the discovered package files and the Elisp files left out."
  (let* ((root (p/repo-root))
         (files (p/discover-files))
         (in-scope (mapcar (lambda (f) (file-relative-name f root)) files))
         (other-el
          (seq-difference
           (seq-filter (lambda (f) (string-suffix-p ".el" f))
                       (p/tracked-files))
           in-scope)))
    (dolist (file files)
      (princ (format "%-9s %s\n" (p/module-class file)
                     (file-relative-name file root))))
    (when other-el
      (princ "\nElisp outside the package (text-hygiene only):\n")
      (dolist (rel other-el)
        (princ (format "          %s\n" rel))))))

(defun p/explain-file (path)
  "Print the class of PATH and which checks apply to it."
  (let* ((root (p/repo-root))
         (full (expand-file-name path root))
         (class (p/module-class full))
         (profile (cdr (assq class (p/config-value :profiles)))))
    (princ (format "%s\n  class: %s\n" (file-relative-name full root)
                   (or class "not inspected by the suite")))
    (when profile
      (princ (format "  profile: headers %S, may-require %S, commentary %S\n"
                     (plist-get profile :headers)
                     (plist-get profile :may-require)
                     (plist-get profile :commentary))))
    (princ "\n")
    (dolist (entry p/check-registry)
      (pcase-let ((`(,name ,_doc ,_fn ,global ,classes) entry))
        (princ (format "  %-24s %s\n"
                       name
                       (cond
                        ((null class) "no (file is not inspected)")
                        ((stringp classes) (format "yes (%s)" classes))
                        (global "yes")
                        ((memq class classes) "yes")
                        (t (format "no (%s not in scope)"
                                   class)))))))))

(defun p/print-check-list ()
  "Print the registered checks as a Markdown table."
  (princ "| check | runs on | description |\n")
  (princ "|---|---|---|\n")
  (dolist (entry p/check-registry)
    (pcase-let ((`(,name ,doc ,_fn ,global ,classes) entry))
      (princ (format "| `%s` | %s | %s |\n"
                     name
                     (cond
                      ((stringp classes) classes)
                      (global "every tracked file")
                      (t (mapconcat #'symbol-name classes ", ")))
                     doc)))))

(defun p/profile-values (class)
  "Return (HEADERS MAY-REQUIRE COMMENTARY) strings for CLASS."
  (let* ((profile (cdr (assq class (p/config-value :profiles))))
         (headers (plist-get profile :headers))
         (targets (plist-get profile :may-require))
         (limits (plist-get profile :commentary))
         (header-parts '()))
    (while headers
      (push (format "%s %s" (pop headers) (pop headers)) header-parts))
    (list (mapconcat #'identity (nreverse header-parts) ", ")
          (mapconcat #'symbol-name targets ", ")
          (format "%s-%s" (plist-get limits :min)
                  (or (plist-get limits :max) "n")))))

(defun p/print-profile-table ()
  "Print the class profiles as a Markdown table."
  (princ "## Class profiles\n\n")
  (princ "| class | headers | may require | commentary lines |\n")
  (princ "|---|---|---|---|\n")
  (dolist (class p/all-classes)
    (let ((values (p/profile-values class)))
      (princ (format "| `%s` | %s | %s | %s |\n"
                     class (nth 0 values) (nth 1 values) (nth 2 values))))))

(defun p/check-table ()
  "Return the check table and the class profiles as a string."
  (concat (with-output-to-string (p/print-check-list))
          "\n"
          (with-output-to-string (p/print-profile-table))))

(defun p/arg-value (flag args)
  "Return the value following FLAG in ARGS, or nil."
  (cadr (member flag args)))

(defun p/main (args)
  "Dispatch on command-line ARGS."
  (setq args (delete "--" (copy-sequence args)))
  (cond
   ((member "--list" args)
    (princ (p/check-table)))
   ((member "--files" args)
    (p/print-file-scope))
   ((p/arg-value "--explain" args)
    (p/explain-file (p/arg-value "--explain" args)))
   (t
    (let ((failed (p/run-checks)))
      (princ (if failed "FAILED\n" "OK\n"))
      (when failed (kill-emacs 1))))))
