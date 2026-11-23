;;; 21-layer-order.el --- module layers, in one direction -*- lexical-binding: t; -*-

;;; Commentary:

;; A package whose architecture has layers has one rule worth enforcing: a
;; module may only require a module of its own layer or of a layer below it.
;; The class profiles in `:profiles' cannot express that, because every
;; business module is of class `business'.
;;
;; A project declares its layers once, in `config/ci.el', top of the stack
;; first.  The order is the direction -- a layer may require itself and any
;; layer above it -- so a stack needs no second table:
;;
;;   :layers ((core contract loop session)
;;            (adapters provider-sse session-jsonl)
;;            (product console tools undo))
;;
;; A shape that is not a stack -- two layers at the same depth that may not
;; see each other -- sets `:layer-may-require' and that table wins.
;;
;; The module name is the file name without the package prefix, so `loop'
;; answers for `lisp/<pkg>-loop.el' -- a shape `module-prefix' already
;; guarantees.  A business module that is missing from `:layers' is reported
;; rather than exempted: an undeclared module is the one a reviewer forgets
;; to place.

;;; Code:

(defun p/layer-table ()
  "Return a hash table mapping module name to layer, or nil."
  (let ((layers (p/config-value :layers)))
    (when layers
      (let ((table (make-hash-table :test #'equal)))
        (dolist (entry layers)
          (dolist (module (cdr entry))
            (puthash (symbol-name module) (car entry) table)))
        table))))

(defun p/module-name (file)
  "Return FILE's module name: its base without the package prefix."
  (let* ((base (file-name-base file))
         (prefix (concat (p/package-name) "-")))
    (if (string-prefix-p prefix base)
        (substring base (length prefix))
      base)))

(defun p/layer-may-require (layer)
  "Return the layers LAYER may require: its own and the ones above it.
The order of `:layers' is the direction, so `(adapters core)' in a stack
written `(core ...) (adapters ...)' is derived rather than written twice.  A
project whose layers are not a stack sets `:layer-may-require', and that
table answers instead."
  (let ((explicit (assq layer (p/config-value :layer-may-require))))
    (if explicit
        (cons layer (cdr explicit))
      (let ((above nil))
        (catch 'found
          (dolist (entry (p/config-value :layers))
            (push (car entry) above)
            (when (eq (car entry) layer) (throw 'found t)))
          nil)
        above))))

(p/defcheck-global layer-order :scope "business modules: the :layers table"
  "A module may only require modules of its own layer or a lower one."
  (let ((table (p/layer-table)))
    (when table
      (let ((units (make-hash-table :test #'equal)))
        (dolist (file files)
          (when (eq (p/module-class file) 'business)
            (puthash (p/module-name file) file units)))
        (dolist (file files)
          (when (eq (p/module-class file) 'business)
            (let ((layer (gethash (p/module-name file) table)))
              (if (null layer)
                  (p/add-error check file nil
                               (format "module `%s' is not in the :layers table"
                                       (p/module-name file)))
                (dolist (feature (p/file-top-level-requires file))
                  (let* ((name (symbol-name feature))
                         (prefix (concat (p/package-name) "-"))
                         (unit (and (string-prefix-p prefix name)
                                    (substring name (length prefix))))
                         (target (and unit (gethash unit table))))
                    (when (and target
                               (not (memq target (p/layer-may-require layer))))
                      (p/add-error check file nil
                                   (format "%s module `%s' may not require %s module `%s'"
                                           layer (p/module-name file)
                                           target unit)))))))))))))
