;;; 16-policy.el --- policy tables and registry agree -*- lexical-binding: t; -*-

;;; Commentary:

;; Guards the policy's own structure, because a silent mistake there
;; disables a rule instead of failing: a class misspelled in a profile or
;; in a check's :classes means that check simply never runs.
;;
;; Checked here: every known class has a profile with all three
;; properties, every class a profile names exists, every header set
;; resolves, and every class a check claims exists.

;;; Code:

(defun p/policy-source ()
  "Return the file that holds the policy, for error reporting."
  (or (symbol-file 'p/config 'defvar) (p/main-file)))

(defun p/check-profile (check source class profile)
  "Validate PROFILE for CLASS; report problems as CHECK at SOURCE."
  (dolist (prop '(:headers :may-require :commentary))
    (unless (plist-get profile prop)
      (p/add-error check source nil
                   (format "class `%s' has no %s in its profile"
                           class prop))))
  ;; :headers must point at a header set.
  (let ((headers (plist-get profile :headers)))
    (dolist (slot '(:require :forbid))
      (let ((value (plist-get headers slot)))
        (cond
         ((null value) nil)
         ((and (keywordp value)
               (assq value (p/config-value :header-sets)))
          nil)
         ((keywordp value)
          (p/add-error check source nil
                       (format "class `%s' uses unknown header set `%s'"
                               class value)))
         (t
          (p/add-error check source nil
                       (format "class `%s' :headers %s must name a header set"
                               class slot)))))))
  ;; :may-require must name known classes.
  (dolist (target (plist-get profile :may-require))
    (unless (memq target p/all-classes)
      (p/add-error check source nil
                   (format "class `%s' may require unknown class `%s'"
                           class target))))
  ;; :commentary must be a plist with a :min.
  (let ((limits (plist-get profile :commentary)))
    (unless (and (listp limits) (plist-get limits :min))
      (p/add-error check source nil
                   (format "class `%s' :commentary needs a :min" class)))))

(p/defcheck-global policy :scope "the policy tables and the check registry"
  "The policy tables and the check registry must agree."
  (let ((known p/all-classes)
        (source (p/policy-source))
        (profiles (p/config-value :profiles)))
    (dolist (class known)
      (let ((profile (cdr (assq class profiles))))
        (if profile
            (p/check-profile check source class profile)
          (p/add-error check source nil
                       (format ":profiles has no entry for class `%s'" class)))))
    (dolist (entry profiles)
      (unless (memq (car entry) known)
        (p/add-error check source nil
                     (format ":profiles names unknown class `%s'" (car entry)))))
    (dolist (entry p/check-registry)
      (let ((name (car entry))
            (classes (nth 4 entry)))
        (when (listp classes)
          (dolist (class classes)
            (unless (memq class known)
              (p/add-error check source nil
                           (format "check `%s' claims unknown class `%s'"
                                   name class)))))))
    ;; :package-headers is the single list everything derives from.
    (let ((vocabulary (p/config-value :package-headers)))
      (unless (and (listp vocabulary) (consp vocabulary))
        (p/add-error check source nil
                     ":package-headers must be a non-empty list"))
      (dolist (item vocabulary)
        (unless (stringp item)
          (p/add-error check source nil
                       (format ":package-headers expects strings, got `%S'"
                               item))))
      (unless (= (length vocabulary)
                 (length (delete-dups (copy-sequence vocabulary))))
        (p/add-error check source nil
                     ":package-headers lists a header twice")))
    ;; Every :header-sets entry must resolve, and :but may only remove
    ;; headers that the vocabulary actually has.
    (dolist (set (p/config-value :header-sets))
      (let ((name (car set))
            (spec (cadr set)))
        (cond
         ((null (p/header-set-entries spec))
          (p/add-error check source nil
                       (format "header set `%s' does not resolve: %S"
                               name spec)))
         ((and (consp spec) (memq (car spec) '(:but :only)))
          (dolist (item (cdr spec))
            (unless (member item (p/config-value :package-headers))
              (p/add-error check source nil
                           (format "header set `%s' names unknown header `%s'"
                                   name item)))))
         ((not (eq spec :all))
          (p/add-error check source nil
                       (format "header set `%s' has an unknown form: %S"
                               name spec))))))))
