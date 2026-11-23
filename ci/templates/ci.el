;;; ci.el --- Project policy for the check suite  -*- lexical-binding: t; -*-

;;; Commentary:

;; Written by ci/bootstrap.sh and owned by this repository: the suite in ci/
;; is shared and gets replaced, this file does not. It is loaded after
;; ci/config.el, so anything set here wins.
;;
;; Only the keys a project usually differs in are listed; the rest come from
;; ci/config.el. Delete a form to take the default back.

;;; Code:

;; Declared by ci/config.el; declared here as well so this file can be
;; byte-compiled on its own without a free-variable warning, which is what a
;; reviewer's byte-compile step would otherwise report.
(defvar p/config)

;; The Emacs floor belongs to the suite, not to this file: a package that
;; declares an older Emacs than the suite runs on fails the check rather than
;; lowering the floor. Nothing here has to be set to start.

;; Where the suite looks for modules, when the layout is not the default.
;; (setq p/config (plist-put p/config :submodule-dir "lisp"))
;; (setq p/config (plist-put p/config :test-dir "test"))
;; (setq p/config (plist-put p/config :vendor-dir "vendor"))

;; Module layers, when the architecture has them: a module may require its own
;; layer or one below. Every module under lisp/ has to appear here or the
;; `layer-order' check reports it, which is the point -- an undeclared module
;; is one nobody placed on purpose.
;; (setq p/config
;;       (plist-put p/config :layers
;;                  '((core contract loop)
;;                    (adapters provider)
;;                    (product console tools))))
;; (setq p/config
;;       (plist-put p/config :layer-may-require
;;                  '((core) (adapters core) (product core adapters))))

;; Decision records need no configuration: `adr-format' checks docs/decisions/
;; when that directory exists, and the path and the file names are fixed by the
;; extension that reads them. Vendored code needs none either: `vendor' is a
;; class with a profile of its own.

;; A benchmark of this package's own hot path belongs in config/perf.el, which
;; ci/perf.el loads when it exists: (p/defperf name "what it measures" body).
;; Its budget goes in the :perf table below, under the same name.

;; Performance budgets, when the defaults do not fit the machine or the code.
;; (setq p/config
;;       (plist-put p/config :perf
;;                  '((insert-per-chunk    :max 0.10)
;;                    (insert-size-ratio   :max 3.0)
;;                    (redisplay-per-chunk :max 4.00)
;;                    (batch-ratio         :min 4.0)
;;                    (filter-events-per-call :max 2.0)
;;                    (filter-gap-spread   :max 25.0)
;;                    (json-per-event      :max 0.10))))

;; Where `make size' looks, and how long a run of lines has to be before it is
;; worth calling copy-paste.  The default is the modules under the submodule
;; directory; `.' adds the entry point at the root, which is a module of its own
;; in a package that keeps its command there.  A package that can count
;; something else -- definitions, promises, endpoints -- puts the function in
;; config/size.el, which ci/size.el loads when it exists, and the report grows
;; a column for it.
;; (setq p/config
;;       (plist-put p/config :size
;;                  '(:directories ("lisp" ".")
;;                    :window 4
;;                    :large 300
;;                    :shown 20
;;                    :skip ("\\`;" "\\`(require" "\\`(provide"))))

;; Coverage instruments the same source set by default.  A package whose
;; modules live elsewhere overrides :coverage the same way; a directory is
;; walked recursively, and "." is the entry point at the root.
;; (setq p/config
;;       (plist-put p/config :coverage
;;                  '(:directories ("lisp" "."))))

(provide 'ci)

;;; ci.el ends here
