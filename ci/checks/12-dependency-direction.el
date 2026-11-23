;;; 12-dependency-direction.el --- module layering -*- lexical-binding: t; -*-

;;; Commentary:

;; A module may only require features whose class is listed in its own
;; class profile's :may-require.  Requires of features outside the
;; repository are ignored.

;;; Code:

(p/defcheck-global dependency-direction :scope "discovered .el files"
  "Module requires must follow the configured layer rules."
  (let ((feature-classes
         (let (tbl)
           (dolist (f files)
             (let ((class (p/module-class f)))
               (when class
                 (push (cons (file-name-base f) class) tbl))))
           tbl)))
    (dolist (file files)
      (let ((from-class (p/module-class file)))
        (when from-class
          (dolist (feature (p/file-top-level-requires file))
            (let ((to-class (cdr (assoc (symbol-name feature)
                                        feature-classes))))
              (when to-class
                (unless (memq to-class (p/class-prop from-class :may-require))
                  (p/add-error check file nil
                               (format "%s may not require %s `%s'"
                                       from-class to-class
                                       (symbol-name feature))))))))))))
