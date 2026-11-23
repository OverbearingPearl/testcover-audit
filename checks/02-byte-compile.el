;;; 02-byte-compile.el --- byte-compile package modules -*- lexical-binding: t; -*-

;;; Commentary:

;; Byte-compiles each file, loading non-test files afterwards.  Before
;; compiling, the file's own top-level requires and the root entry
;; module are loaded so defcustom/defvar forms are known as special
;; variables at compile time.
;;
;; For test modules two warning categories are disabled.  `lexical' is what
;; reports "global/dynamic var lacks a prefix", a naming convention for
;; published code that test modules are exempt from.  `unresolved' is what
;; reports a call to a function that does not exist yet, which is the first
;; step of a TDD cycle: the test names the API before it is written.  The
;; typo it would otherwise catch is still caught, one step later, when ERT
;; runs the test; `declare-function' would be the other way to say the same
;; thing and `banned-construct' forbids it.

;;; Code:

(p/defcheck byte-compile :classes (main business test)
  "Byte-compile each file; non-test files are loaded afterwards."
  (let* ((dest (make-temp-file "elisp-check-" nil ".elc"))
         (compile-log-buf (get-buffer-create "*Compile-Log*")))
    (unwind-protect
        (progn
          (with-current-buffer compile-log-buf
            (let ((inhibit-read-only t))
              (erase-buffer)))
          (let ((inhibit-message t)
                (byte-compile-verbose nil)
                (byte-compile-warnings
                 (if (p/test-file-p file)
                     '(not lexical unresolved)
                   byte-compile-warnings))
                (byte-compile-dest-file-function (lambda (_f) dest)))
            (dolist (feature (p/file-top-level-requires file))
              (condition-case nil
                  (require feature)
                (error nil)))
            (condition-case nil
                (require (intern (p/package-name)))
              (error nil))
            (when (byte-compile-file file)
              (unless (p/test-file-p file)
                (condition-case nil
                    (load dest nil t)
                  (error nil))))))
      (when (file-exists-p dest)
        (delete-file dest)))
    (let ((log (string-trim (with-current-buffer compile-log-buf
                              (buffer-string)))))
      (unless (string-empty-p log)
        (dolist (line (split-string log "\n" t))
          (p/add-error check file nil line))))))
