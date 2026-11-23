;;; 07-meta-info.el --- header and Commentary requirements -*- lexical-binding: t; -*-

;;; Commentary:

;; Enforces the header requirements in the policy's :headers table per
;; module class, keeps the Commentary within the per-class line limits,
;; and validates Keywords against finder-known-keywords for non-test
;; files.

;;; Code:

(require 'finder)
(require 'seq)

(defun p/header-lines (lines)
  "Return (line . text) pairs for the leading header block of LINES."
  (let ((out '())
        (in-header t)
        (n 0))
    (dolist (line lines)
      (setq n (1+ n))
      (when in-header
        (if (or (p/blank-line-p line)
                (string-prefix-p ";;" line))
            (push (cons n line) out)
          (setq in-header nil))))
    (nreverse out)))

(defun p/header-set-entries (spec)
  "Return the header names described by SPEC.
SPEC is `:all' for the whole :package-headers list, (:but NAME...) for
that list without the named entries, or (:only NAME...) for just those."
  (let ((all (p/config-value :package-headers)))
    (cond
     ((eq spec :all) all)
     ((and (consp spec) (eq (car spec) :but))
      (seq-difference all (cdr spec)))
     ((and (consp spec) (eq (car spec) :only))
      (seq-intersection all (cdr spec)))
     (t nil))))

(defun p/header-set (value)
  "Return VALUE as a list of header prefixes.
VALUE is a list or the name of an entry in :header-sets.  An unknown set
name yields nil here; the `policy' check reports it, so one broken policy
entry does not abort the whole run."
  (cond
   ((null value) nil)
   ((keywordp value)
    (p/header-set-entries (cadr (assq value (p/config-value :header-sets)))))
   ((listp value) value)
   (t nil)))

(defun p/meta-present-p (prefix header-lines)
  "Return non-nil when some header line starts with PREFIX."
  (let ((found nil))
    (dolist (hl header-lines)
      (when (p/meta-line-p (cdr hl) prefix)
        (setq found t)))
    found))

(p/defcheck meta-info
  "Header rules per class; per-class Commentary limits; known Keywords."
  (let* ((lines (p/file-lines file))
         (is-test (eq class 'test))
         (header-lines (p/header-lines lines))
         (rule (p/class-prop class :headers)))
    ;; Required and forbidden header lines.
    (progn
      (dolist (prefix (p/header-set (plist-get rule :require)))
        (unless (p/meta-present-p (concat ";; " prefix) header-lines)
          (p/add-error check file nil
                       (format "missing meta line `;; %s' in %s module"
                               prefix class))))
      (dolist (prefix (p/header-set (plist-get rule :forbid)))
        (dolist (hl header-lines)
          (when (p/meta-line-p (cdr hl) (concat ";; " prefix) t)
            (p/add-error check file (car hl)
                         (format "forbidden meta line `;; %s' in %s file"
                                 prefix class))))))
    ;; Commentary must be present and within the class's line limits.
    (let* ((commentary-idx nil)
           (body-lines 0)
           (limits (p/class-prop class :commentary))
           (min-lines (or (plist-get limits :min) 1))
           (max-lines (plist-get limits :max)))
      (dotimes (i (length header-lines))
        (when (and (null commentary-idx)
                   (p/meta-line-p (cdr (nth i header-lines))
                                  ";;; Commentary"))
          (setq commentary-idx i)))
      (unless commentary-idx
        (p/add-error check file nil "missing meta line `;;; Commentary'"))
      (when commentary-idx
        (dolist (pair (nthcdr (1+ commentary-idx) header-lines))
          (when (and (string-prefix-p ";;" (cdr pair))
                     (not (string-prefix-p ";;;" (cdr pair)))
                     (not (p/blank-line-p
                           (string-trim-left (substring (cdr pair) 2)))))
            (setq body-lines (1+ body-lines))))
        (when (< body-lines min-lines)
          (p/add-error check file nil
                       (format "`;;; Commentary' needs at least %d descriptive line%s for a %s module"
                               min-lines (if (= min-lines 1) "" "s") class)))
        (when (and max-lines (> body-lines max-lines))
          (p/add-error check file nil
                       (format "`;;; Commentary' allows at most %d descriptive line%s for a %s module"
                               max-lines (if (= max-lines 1) "" "s") class)))))
    ;; Keywords must be known to finder (non-test files only).
    (unless is-test
      (let ((known (mapcar (lambda (kw) (downcase (symbol-name (car kw))))
                           finder-known-keywords)))
        (dolist (hl header-lines)
          (when (string-prefix-p ";; Keywords:" (cdr hl))
            (let* ((raw (string-trim (substring (cdr hl)
                                                (length ";; Keywords:"))))
                   (kws (split-string raw p/keyword-sep-rx t)))
              (if (null kws)
                  (p/add-error check file (car hl) "empty Keywords: line")
                (dolist (kw kws)
                  (unless (member (downcase kw) known)
                    (p/add-error check file (car hl)
                                 (format "unknown keyword `%s'" kw))))))))))))
