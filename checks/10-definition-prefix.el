;;; 10-definition-prefix.el --- definitions carry the module name -*- lexical-binding: t; -*-

;;; Commentary:

;; Every top-level definition is namespaced by the module it lives in: the
;; prefix is the module's full name, the file name without `.el', not just
;; the package name.  `lisp/<pkg>-loop.el' therefore defines
;; `pkg-loop-...', and `test/loop-tests.el' defines `loop-tests-...'.
;;
;; The rule is the same for functions, variables, macros, aliases,
;; customisations, ERT tests, structs, classes and generics, and modes
;; additionally end in `-mode'.  `cl-defmethod' is not covered on purpose:
;; its name belongs to the generic it extends, which may be another
;; package's.  Two exemptions:
;;
;;   - the main module may define an entry command named exactly the
;;     package, because that is what users type;
;;   - tooling modules are shared code that must not name the package at
;;     all (see `project-neutral'), so their definitions are free.
;;
;; Vendored code keeps its own names and is not checked.

;;; Code:

(defun p/definition-prefix (file)
  "Return the prefix a definition in FILE must carry."
  (concat (file-name-base file) "-"))

(defun p/main-entry-command-p (name kind is-main repo)
  "Return non-nil when NAME is the main module's entry command.
KIND is the defining form, IS-MAIN says the module is the main one, and
REPO is the package name."
  (and is-main (eq kind 'defun) (string= name repo)))

(defun p/definition-name (form)
  "Return the symbol FORM names, or nil when it has no name.
`defalias' takes its name quoted, and `cl-defstruct' accepts either a
symbol or a cons of name and options; both are read the same way here."
  (let ((name (cadr form)))
    (cond
     ((and (consp name) (eq (car name) 'quote)) (cadr name))
     ((and (eq (car form) 'cl-defstruct) (consp name)) (car name))
     (t name))))

(defun p/mode-name-ok-p (name prefix)
  "Return non-nil when NAME is a mode under PREFIX."
  (and (string-prefix-p prefix name)
       (string-suffix-p "-mode" name)))

(p/defcheck definition-prefix :classes (main business test)
  "Every definition starts with the name of the module it lives in."
  (let* ((prefix (p/definition-prefix file))
         (repo (p/package-name))
         (is-main (eq class 'main))
         (def-kinds (p/config-value :def-kinds)))
    (pcase-dolist (`(,form . ,line) (p/top-level-forms file))
      (when (consp form)
        (let ((kind (car form))
              (name (p/definition-name form)))
          (when (symbolp name)
            (let ((nm (symbol-name name)))
              (cond
               ((memq kind def-kinds)
                (unless (or (p/main-entry-command-p nm kind is-main repo)
                            (string-prefix-p prefix nm))
                  (p/add-error check file line
                               (format "`%s' must start with `%s'"
                                       name prefix))))
               ((memq kind '(define-minor-mode define-derived-mode))
                (unless (p/mode-name-ok-p nm prefix)
                  (p/add-error check file line
                               (concat (if (eq kind 'define-minor-mode)
                                           "minor mode"
                                         "mode")
                                       " `" nm
                                       "' must start with `" prefix
                                       "' and end with `-mode'"))))))))))))
