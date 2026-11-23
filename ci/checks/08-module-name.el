;;; 08-module-name.el --- provide form matches filename -*- lexical-binding: t; -*-

;;; Commentary:

;; Every package module must provide a feature named after its own file,
;; and that `(provide ...)' must be the last form.  Putting it last is
;; what makes a partially loaded file fail loudly: if anything above it
;; errors, the feature is never marked as provided.
;;
;; Only real top-level forms count, so a commented-out provide is not
;; mistaken for a real one.

;;; Code:

(defun p/quote-unwrap (form)
  "Return FORM with a leading quote removed."
  (if (and (consp form) (eq (car form) 'quote))
      (cadr form)
    form))

(defun p/provide-forms (forms)
  "Return (LINE . FEATURE) for each top-level provide among FORMS."
  (let ((out '()))
    (pcase-dolist (`(,form . ,line) forms)
      (when (and (consp form) (eq (car form) 'provide))
        (push (cons line (p/quote-unwrap (cadr form))) out)))
    (nreverse out)))

(p/defcheck module-name :classes (main business test)
  "The file must provide its own filename base, as its last form."
  (let* ((base (intern (file-name-base file)))
         (forms (p/top-level-forms file))
         (provides (p/provide-forms forms))
         (provide-line nil)
         (last-form (car (car (last forms)))))
    (dolist (entry provides)
      (when (eq (cdr entry) base)
        (setq provide-line (car entry))))
    (cond
     ((null forms)
      (p/add-error check file nil "file has no top-level forms"))
     ((null provide-line)
      (p/add-error check file nil
                   (format "missing (provide '%s) to match filename" base)))
     ((not (and (consp last-form)
                (eq (car last-form) 'provide)
                (eq (p/quote-unwrap (cadr last-form)) base)))
      (p/add-error check file provide-line
                   (format "(provide '%s) must be the last form" base)))
     (t nil))))
