;;; 03-blank-lines.el --- blank line rule -*- lexical-binding: t; -*-

;;; Commentary:

;; At most one consecutive blank line, in every class the suite checks.
;; `vendor/' is not one of them, so a vendored file is never restyled.
;;
;; The count is fixed rather than configurable, and that is the decision
;; this file exists to state.  Every other styling rule here can point at
;; an authority -- checkdoc, package-lint, the Emacs Lisp manual on heading
;; comments -- and this one cannot: "at most one" is this tree's habit, not
;; a convention, and two blank lines between top-level forms is ordinary
;; Emacs Lisp.  So the rule is either real or it is not.  A number a
;; project may change is not a rule, and a rule nobody may change has to be
;; written down as one instead of hiding behind a key that exists only to
;; be left alone.  A copy of the suite that disagrees deletes the check.

;;; Code:

(p/defcheck blank-lines
  "At most one consecutive blank line."
  (let ((line-num 0)
        (blank-run 0)
        (last-blank-start nil))
    (dolist (line (p/file-lines file))
      (setq line-num (1+ line-num))
      (if (p/blank-line-p line)
          (progn
            (when (= blank-run 0)
              (setq last-blank-start line-num))
            (setq blank-run (1+ blank-run)))
        (progn
          (when (> blank-run 1)
            (p/add-error check file last-blank-start
                         (format "%d consecutive blank lines" blank-run)))
          (setq blank-run 0))))
    (when (> blank-run 1)
      (p/add-error check file last-blank-start
                   (format "%d consecutive blank lines" blank-run)))))
