;;; 09-module-prefix.el --- the file name carries the right prefix -*- lexical-binding: t; -*-

;;; Commentary:

;; A module name is the file name without its extension, and the package
;; prefix belongs in exactly one place in the tree:
;;
;;   lisp/<pkg>-<name>.el   required: the module is published, and its
;;                          definitions are namespaced with the same string
;;   test/<name>-tests.el   forbidden: a test is not published, and the
;;                          package name in every test file is noise
;;   ci/<name>.el           forbidden: the copyable tree must not name the
;;                          package at all (`project-neutral' enforces it)
;;
;; The main file is the package: its base name is where the package name
;; comes from, so there is nothing to compare.  A business module needs a
;; name after the prefix (`<pkg>-.el' and `<pkg>--name.el' both fail), and
;; vendored code carries somebody else's prefix, so it is exempt.
;;
;; Only the package prefix is decided here.  Whether the definitions inside
;; a module carry its full name is `definition-prefix'; whether a test
;; module ends in `-tests' is `test-suffix'.

;;; Code:

(defun p/package-prefix ()
  "Return the package prefix, including the trailing hyphen."
  (concat (p/package-name) "-"))

(p/defcheck module-prefix :classes (business test tooling)
  "lisp/ names start with the package prefix; test/ and ci/ names do not."
  (let* ((base (file-name-base file))
         (pkg (p/package-name))
         (prefix (p/package-prefix))
         (has-prefix (string-prefix-p prefix base)))
    (pcase class
      ('business
       (cond
        ((not has-prefix)
         (p/add-error check file nil
                      (format "business module `%s.el' must start with `%s'"
                              base prefix)))
        ((= (length base) (length prefix))
         (p/add-error check file nil
                      (format "business module `%s.el' has no name after `%s'"
                              base prefix)))
        ((string-prefix-p (concat prefix "-") base)
         (p/add-error check file nil
                      (concat "business module `" base
                              ".el' repeats the package prefix; the "
                              "module name must not start with `-'")))))
      ((or 'test 'tooling)
       (when (or has-prefix (string= base pkg))
         (p/add-error check file nil
                      (concat (symbol-name class) " module `" base
                              ".el' must not carry the package prefix `"
                              prefix "'")))))))
