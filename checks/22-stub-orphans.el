;;; 22-stub-orphans.el --- a stub goes when the real definition lands -*- lexical-binding: t; -*-

;;; Commentary:

;; A project that writes its tests before its code needs something to stand
;; in for the code, or every story fails with a void-function that says
;; nothing about which story is which.  The usual stand-in is a map of
;; names to a placeholder definition, and it is invisible when it rots: the
;; placeholder only defines a function that is not already defined, so a
;; module that lands leaves its entry harmless, and the story passes against
;; the real code while nobody learns the entry is still there.
;;
;; The map is the project's, so this check is silent unless a project names
;; one.  When it does, a name that is stubbed and defined is reported: the
;; entry has to go in the commit that makes its story pass, because after
;; that nothing else can tell it apart from a stub for code that is missing.
;;
;; Only definitions in the source directories count.  The map itself
;; defines every name it lists -- that is what a placeholder is -- so a map
;; that counted as a source would report itself clean forever.

;;; Code:

(require 'seq)

(defconst p/stub-def-forms
  '(defun defsubst defmacro cl-defun cl-defmacro defalias)
  "Forms whose second element names a function.

`defalias' takes it quoted, the rest take it bare; both are read the same
way here, because the question is which name is defined and not how.")

(defun p/stub-config ()
  "Return the `:stubs' configuration, or nil when the project has none."
  (p/config-value :stubs))

(defun p/stub-map-file (config)
  "Return the absolute path of the stub map named by CONFIG."
  (expand-file-name (plist-get config :file) (p/repo-root)))

(defun p/stub-form (config)
  "Return the placeholder form named by CONFIG."
  (plist-get config :form))

(defun p/stub-sources (config)
  "Return absolute directories holding real definitions, per CONFIG."
  (let ((root (p/repo-root)))
    (mapcar (lambda (dir) (expand-file-name dir root))
            (or (plist-get config :sources) (list (p/config-value :submodule-dir))))))

(defun p/read-forms (file)
  "Return the top-level forms in FILE, or nil when it does not read."
  (when (file-regular-p file)
    (with-temp-buffer
      (insert-file-contents-literally file)
      (goto-char (point-min))
      (let ((forms '())
            (done nil))
        (while (not done)
          (condition-case nil
              (let ((form (read (current-buffer))))
                (if form (push form forms) (setq done t)))
            (end-of-file (setq done t))
            (error (setq done t))))
        (nreverse forms)))))

(defun p/walk-forms (form fn)
  "Call FN on FORM and on every form nested inside it."
  (when (consp form)
    (funcall fn form)
    (p/walk-forms (car form) fn)
    (p/walk-forms (cdr form) fn)))

(defun p/name-of (form)
  "Return the symbol FORM names, or nil when it names nothing."
  (let ((name nil))
    (cond
     ((and (memq (car form) p/stub-def-forms) (cadr form))
      (setq name (cadr form)))
     ((and (eq (car form) 'define-advice) (cadr form))
      (setq name (cadr form))))
    (cond
     ((null name) nil)
     ((and (consp name) (eq (car name) 'quote)) (cadr name))
     (t name))))

(defun p/stubbed (forms form-name)
  "Return the names stubbed in FORMS by a call to FORM-NAME."
  (let ((names '()))
    (dolist (form forms)
      (p/walk-forms
       form
       (lambda (node)
         (when (and (eq (car node) form-name)
                    (symbolp (cadr node))
                    (cadr node))
           (push (cadr node) names)))))
    (nreverse names)))

(defun p/defined (file)
  "Return (NAME . FILE) for every function FILE defines at top level."
  (let ((names '()))
    (dolist (form (p/read-forms file))
      (let ((name (p/name-of form)))
        (when (and (symbolp name) name)
          (push (cons name file) names))))
    (nreverse names)))

(p/defcheck-global stub-orphans :scope "the stub map a project names"
  "A name the stub map lists is deleted once a module defines it."
  (let ((config (p/stub-config)))
    (when config
      (let* ((map (p/stub-map-file config))
             (stubbed (p/stubbed (p/read-forms map) (p/stub-form config)))
             (defined
              (apply #'append
                     (mapcar (lambda (dir)
                               (apply #'append
                                      (mapcar #'p/defined
                                              (seq-filter
                                               (lambda (f) (string-suffix-p ".el" f))
                                               (directory-files dir t)))))
                             (p/stub-sources config)))))
        (dolist (name stubbed)
          (let ((hit (assq name defined)))
            (when hit
              (p/add-error
               check map nil
               (format "`%s' is stubbed here and defined in %s; the stub outlives its module"
                       name
                       (file-relative-name (cdr hit) (p/repo-root)))))))))))
