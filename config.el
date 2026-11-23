;;; config.el --- Project policy for the check suite -*- lexical-binding: t; -*-

;;; Commentary:

;; Single source of policy.  Everything a check is allowed to tune lives
;; here.

;; The layout this policy describes is the standard MELPA one:
;;
;;   <pkg>.el            package entry point, the only .el at the repo root
;;   lisp/<pkg>-*.el     business modules, carrying the package prefix
;;   test/*-tests.el     test modules, without it
;;   ci/*.el             tooling: style checks only, no packaging rules
;;
;; Nothing else needs to change when this tree is copied into another
;; package with that layout.
;;
;; Naming is three strings and two comparisons (see `module-prefix',
;; `definition-prefix' and `test-suffix'): the module name against the
;; package name, and each definition against its module's full name.  The
;; package name is the main file's base name, so the main module and the
;; package are the same string by definition.  A test module is not
;; published, so it carries no package prefix, but its definitions are
;; still prefixed with the module name: `test/loop-tests.el' defines
;; `loop-tests-...'.  `vendor/' is exempt from every naming rule.

;;; Code:

(defvar p/config
  '(:emacs-versions ("29.4")
    :submodule-dir "lisp"
    :test-dir "test"
    :tooling-dir "ci"
    :vendor-dir "vendor"

    ;; Module layers, when the architecture has them.  `:layers' maps a layer
    ;; name to the module names inside it -- the module name is the file name
    ;; without the package prefix.  The order is the direction: a layer may
    ;; require itself and any layer listed above it, so a stack needs no second
    ;; table.  `:layer-may-require' is for a shape that is not a stack and
    ;; wins over the order when set.  Nil `:layers' disables `layer-order'; a
    ;; business module missing from it is reported rather than exempted.
    :layers nil
    :layer-may-require nil

    ;; Which module classes a given class may require.  Features outside
    ;; the repository are ignored.
    ;; What a module class *is*, in one table.  Every question a check
    ;; asks about a class is answered here: which headers it must (or
    ;; must not) carry, which classes it may require, and how long its
    ;; Commentary may be.  A class missing from this table is a mistake,
    ;; never a deliberate exemption; the `policy' check enforces that.
    ;;
    ;;   :headers      (:require SET) or (:forbid SET), see :header-sets
    ;;   :may-require  classes this class may `require'
    ;;   :commentary   (:min N :max M), nil :max means unbounded
    ;;
    ;; Published modules carry the package headers and need room to say
    ;; what they do.  Test and tooling modules are not published, so they
    ;; forbid the package headers (a `;; Version:' line in a file that is
    ;; not a package module is a false claim about the file) and keep
    ;; their Commentary short.
    :profiles
    ((main     :headers (:require :package)
               :may-require (business)
               :commentary (:min 2 :max nil))
     (business :headers (:require :submodule :forbid :entry-only)
               :may-require (business)
               :commentary (:min 2 :max nil))
     (test     :headers (:forbid :package)
               ;; A test may lean on a vendored package: that is what
               ;; `vendor/' is for.
               :may-require (main business test vendor)
               :commentary (:min 1 :max 3))
     (tooling  :headers (:forbid :package)
               :may-require (tooling)
               :commentary (:min 1 :max nil))
     ;; Vendored code is somebody else's file under somebody else's license.
     ;; The class exists so the policy can answer for it, not so the rules
     ;; apply: no headers are required or forbidden, the Commentary is not
     ;; ours to shorten, whitespace in a copy is the copy's business, and a
     ;; vendored module may only require another vendored one.
     (vendor   :headers (:require ())
               :may-require (vendor)
               :commentary (:min 0 :max nil)))

    ;; Every header line that marks a file as package metadata.  This is
    ;; the only place these strings appear; the sets below are derived.
    :package-headers
    ("Copyright" "Author" "Assisted-by" "URL" "Version"
     "SPDX-License-Identifier" "Package-Requires" "Keywords")

    ;; Three views of that one list:
    ;;   :package    every package header (the entry point carries all of
    ;;               them; files that are not the package carry none)
    ;;   :submodule  all but the entry-point-only ones
    ;;   :entry-only the entry-point-only ones, forbidden in submodules:
    ;;               a module does not version itself and does not
    ;;               declare its own dependencies or keywords
    :header-sets
    ((:package    :all)
     (:submodule  (:but "Version" "Package-Requires" "Keywords"))
     (:entry-only (:only "Version" "Package-Requires" "Keywords")))

    ;; Banned constructs: regex -> suggested replacement.
    :banned ((";; package-lint: disable" .
              "fix the underlying issue instead of suppressing it")
             ("\\_<declare-function\\_>" .
              "require the providing feature instead")
             ("\\_<ignore-errors\\_>" .
              "use condition-case with a specific error type")
             ("\\_<eval-and-compile\\_>" .
              "move the form or require it explicitly")
             ("\\_<when-let\\_>" . "use when-let* instead")
             ("\\_<if-let\\_>" . "use if-let* instead"))

    ;; Definition forms subject to the module prefix rule.  `cl-defmethod'
    ;; is absent on purpose: its name is the generic's, and a method for
    ;; another package's generic must not be forced into our prefix.
    :def-kinds (defun defmacro defsubst defvar defvar-local defcustom
                defconst defalias cl-defun cl-defmacro cl-defgeneric
                cl-defstruct defclass ert-deftest)

    :commentary-width 80

    ;; Budgets for `make perf'.  Absolute numbers are generous multiples of
    ;; the measurements recorded in docs/architecture.md, wide enough to pass
    ;; on a loaded laptop; a ratio is used where a slow machine would
    ;; otherwise fail a good implementation.  `:max' fails above the value,
    ;; `:min' fails below it.
    :perf
    ((insert-per-chunk      :max 0.10)  ; measured 0.001 ms
     (insert-size-ratio     :max 3.0)   ; measured about 1.0: no O(n) insert
     (redisplay-per-chunk   :max 4.00)  ; measured 0.94 to 1.86 ms
     (batch-ratio           :min 4.0)   ; measured about 8x
     (filter-events-per-call :max 2.0)  ; measured 1.0: no coalescing
     (filter-gap-spread     :max 25.0)  ; measured 1 to 8 ms depending on load
     (json-per-event        :max 0.10))  ; measured 0.01 to 0.03 ms

    ;; How `make size' reads the tree, in one table.  `:directories' are
    ;; relative to the repository root (`.' is the root itself, for a package
    ;; whose entry point is a module of its own); `:skip' is what makes a line
    ;; not worth comparing in this language -- a comment or an import, which
    ;; every file has and no two files share a thought in; `:window' is how
    ;; many consecutive significant lines make a run worth calling copy-paste
    ;; (three is a shape two modules share by accident); `:large' is the
    ;; length at which a module is named, and `:shown' how many runs are
    ;; printed, because a list nobody finishes reading is a list nobody reads.
    :size (:directories ("lisp" ".")
           :window 4
           :large 300
           :shown 20
           :skip ("\\`;" "\\`(require" "\\`(provide"))

    ;; Where `make coverage' instruments the code, in one table.  The same
    ;; `:directories' spelling as `:size': `.' is the entry point at the root,
    ;; and a directory is walked recursively.  Test and vendored files are
    ;; never instrumented, whether or not they sit under a directory named
    ;; here, because coverage of the tests would only say the tests ran.
    :coverage (:directories ("lisp" ".")))
  "Project-wide policy for the check suite.")

(defun p/config-load-project ()
  "Load the project's own overrides, when it has any.
The suite is shared and gets replaced wholesale; the project's policy is
`config/ci.el` next to it, which a replacement never touches. Absent is a
normal state: the defaults above then apply."
  (let* ((here (file-name-directory (or load-file-name buffer-file-name)))
         (project (expand-file-name "../config/ci.el" here)))
    (when (file-exists-p project)
      (load project nil t))))

(p/config-load-project)

(defun p/config-value (key)
  "Return the value for KEY in `p/config'."
  (plist-get p/config key))

(defun p/class-prop (class prop)
  "Return property PROP of module CLASS from the :profiles table."
  (plist-get (cdr (assq class (p/config-value :profiles))) prop))

(defun p/config-export (args)
  "Print the value named by the first element of ARGS.
Keys are `submodule' (the business module directory), `test-dir' (the
test module directory), `vendor' (the vendored-code directory), `main'
(main file basename), `package' and `version'."
  (setq args (delete "--" (copy-sequence args)))
  (let ((key (car args)))
    (princ
     (pcase key
       ("submodule" (p/config-value :submodule-dir))
       ("test-dir" (p/config-value :test-dir))
       ("vendor" (or (p/config-value :vendor-dir) "vendor"))
       ("main" (file-name-nondirectory (p/main-file)))
       ("package" (p/package-name))
       ("version" (or (p/package-version) ""))
       (_ (error "Unknown export key: %S" key))))))
