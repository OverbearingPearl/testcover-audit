;;; 11-test-suffix.el --- test modules end in -tests -*- lexical-binding: t; -*-

;;; Commentary:

;; A test module is named `<name>-tests.el'.  The suffix says what the file
;; is without opening it, and it is what MELPA's default file spec excludes,
;; so tests never reach a published tarball.
;;
;; The rest of the name is free of the package prefix: `module-prefix'
;; forbids one in `test/', because a test module is not published.  The
;; suffix still has to leave a name in front of it: `<...>-.el' with no
;; module name claims nothing.

;;; Code:

(p/defcheck test-suffix :classes (test)
  "Test module names end with `-tests'."
  (let ((base (file-name-base file)))
    (unless (and (string-suffix-p "-tests" base)
                 (> (length base) (length "-tests")))
      (p/add-error check file nil
                   (format "test module `%s.el' must be named `<name>-tests.el'"
                           base)))))
