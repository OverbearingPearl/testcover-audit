;;; 20-adr-format.el --- decision records keep one shape -*- lexical-binding: t; -*-

;;; Commentary:

;; A decision log is only checkable while every record has the same shape: a
;; number that the file name and the record agree on, a status drawn from a
;; closed vocabulary, and the sections that carry the argument.  Without this
;; a record can claim to be accepted while its status says otherwise, and the
;; log becomes a description of decisions rather than a place where they are
;; settled.
;;
;; The path and the file name are not a matter of taste: `docs/decisions',
;; and `NNNN-kebab-title.md', with four digits and no prefix.  Those two are
;; what the `pi' extension that injects the decision index into an agent's
;; prompt matches, and a record it cannot see is a record that does not
;; veto anything.  A directory that keeps its records somewhere else, or a
;; name with an `ADR-' prefix, is reported rather than accommodated.
;;
;; A record also has to name the routes it did not take and the price of the
;; one it took: `## Options considered', and a `Cost:' line.  Both are in the
;; shape this repository's own records follow, and both are the sections an
;; author drops first when the answer felt obvious while writing it.
;;
;; What a record *says* is a separate question, and two shapes are accepted
;; because two are in the wild and both are readable.  The front-matter shape
;; is MADR's: YAML with `status' and `date', a title heading, then the argued
;; sections.  The plain shape is Nygard's: a numbered heading, a `Date:'
;; line, `## Status', and the same sections.  A file is asked to be one of
;; them rather than a mixture.  MADR constrains content only -- no directory,
;; no file name -- so accepting it here costs the naming rule nothing.

;;; Code:

(require 'seq)

(defconst p/adr-dir-name "docs/decisions"
  "Where records live, fixed.
The `pi' extension that reads this directory hardcodes it, so a project that
keeps records elsewhere has no index in its agent's prompt, and the check says
so instead of pretending the records are fine.")

(defconst p/adr-name-rx
  (rx bos (group (= 4 digit)) "-" (+ (not ?/)) ".md" eos)
  "Regexp matching an ADR file name, capturing its number.
Four digits, no prefix, for the same reason: the index extension matches
`^[0-9]{4}-'.")

(defconst p/adr-statuses
  '("draft" "proposed" "accepted" "approved" "rejected" "deprecated"
    "superseded" "amended")
  "Every status an ADR may carry, lower-cased.")

(defconst p/adr-generated-names
  '("decisions.md")
  "Markdown files in the directory that are not records.
One entry, because one is generated: the table of contents the recording tool
writes.  Anything else in the directory is a record and is named like one.")

(defun p/dir-md-files (dir)
  "Return the Markdown files directly inside DIR, sorted."
  (when (file-directory-p dir)
    (sort (seq-filter (lambda (f) (and (file-regular-p f)
                                       (string-suffix-p ".md" f)))
                      (directory-files dir t))
          #'string<)))

(defun p/adr-dir ()
  "Return the absolute decision directory, or nil when there is none."
  (let ((dir (expand-file-name p/adr-dir-name (p/repo-root))))
    (and (file-directory-p dir) dir)))

(defun p/adr-files ()
  "Return (FILE . PLACE) for every record in the decision directory.
PLACE is `top' or `superseded'."
  (let ((dir (p/adr-dir)))
    (when dir
      (append
       (mapcar (lambda (f) (cons f 'top)) (p/dir-md-files dir))
       (mapcar (lambda (f) (cons f 'superseded))
               (p/dir-md-files (expand-file-name "superseded" dir)))))))

(defun p/adr-blank-line-p (line)
  "Return non-nil when LINE holds only blanks."
  (string-empty-p (string-trim (or line ""))))

(defun p/adr-heading-text (line)
  "Return LINE without its leading hashes and blanks."
  (let ((start (string-match "[^# \t]" line)))
    (if start (string-trim (substring line start)) "")))

(defun p/adr-heading-p (text name)
  "Return non-nil when heading TEXT names NAME, ignoring case."
  (string= (downcase (string-trim text)) (downcase name)))

(defun p/adr-front-matter-end (lines)
  "Return the index of the line closing front matter in LINES, or nil."
  (when (and lines (string= "---" (string-trim (car lines))))
    (let ((index 1)
          (found nil))
      (while (and lines (not found))
        (when (and (< index (length lines))
                   (string= "---" (string-trim (nth index lines))))
          (setq found index))
        (setq index (1+ index)))
      found)))

(defun p/adr-unquote (value)
  "Return VALUE without one pair of surrounding quotes, if it has them."
  (let ((length (length value)))
    (if (and (> length 1)
             (memq (aref value 0) '(?\" ?'))
             (eq (aref value 0) (aref value (1- length))))
        (substring value 1 -1)
      value)))

(defun p/adr-front-matter (lines end)
  "Return an alist of key to value from LINES up to END."
  (let ((pairs '()))
    (dolist (line (seq-take (seq-drop lines 1) (1- end)))
      (when (string-match (rx line-start (group (+ (not (any ":")))) ":"
                              (* blank) (group (* nonl)) line-end)
                          line)
        (push (cons (intern (downcase (string-trim (match-string 1 line))))
                    ;; YAML quotes a value that holds a colon, and every
                    ;; `ADR-NNNN: Title' does, so the quotes come off here.
                    (p/adr-unquote (string-trim (match-string 2 line))))
              pairs)))
    (nreverse pairs)))

(defun p/adr-section-value (lines heading)
  "Return the first non-blank line after HEADING in LINES, and its number."
  (let ((index 0)
        (found nil))
    ;; The bound is the list, not its emptiness: a record with no such section
    ;; must be reported, and reaching past the last line would signal instead.
    (while (and (< index (length lines)) (not found))
      (when (and (string-match-p (rx line-start "##") (nth index lines))
                 (p/adr-heading-p (p/adr-heading-text (nth index lines))
                                  heading))
        (let ((next (1+ index)))
          (while (and (< next (length lines))
                      (p/adr-blank-line-p (nth next lines)))
            (setq next (1+ next)))
          (setq found (cons (and (< next (length lines))
                                 (not (string-prefix-p "#" (nth next lines)))
                                 (string-trim (nth next lines)))
                            (1+ next)))))
      (setq index (1+ index)))
    found))

(defun p/adr-has-section-p (lines names)
  "Return non-nil when LINES has a heading of any level among NAMES."
  (let ((found nil))
    (dolist (line lines)
      (when (and (not found)
                 (string-match-p (rx line-start (+ "#") blank) line))
        (let ((text (p/adr-heading-text line)))
          (when (seq-find (lambda (name) (p/adr-heading-p text name)) names)
            (setq found t)))))
    found))

(defun p/adr-check-title (check file lines number)
  "Report a title in FILE that does not agree with NUMBER."
  (let ((title (seq-find (lambda (line)
                           (string-match-p (rx line-start "#" blank) line))
                         lines)))
    (cond
     ((null title)
      (p/add-error check file nil "record has no title heading"))
     ((string-match (rx (group (+ digit)) "." (+ blank)) title)
      (unless (= (string-to-number number)
                 (string-to-number (match-string 1 title)))
        (p/add-error check file nil
                     (format "title says %s but the file name says %s"
                             (match-string 1 title) number)))))))

(defun p/adr-check-sections (check file lines)
  "Report sections missing from FILE's LINES."
  (let ((required '(("context" "context and problem statement")
                    ("options considered" "considered options" "alternatives"
                     "considered alternatives")
                    ("decision" "decision outcome")
                    ("consequences"))))
    (dolist (group required)
      (unless (p/adr-has-section-p lines group)
        (p/add-error check file nil
                     (format "missing a `%s' section" (capitalize (car group))))))
    ;; A choice with no stated price is not a choice, and the line that states
    ;; it is the one an author skips when the price is embarrassing.
    (unless (seq-find (lambda (line)
                        (string-match-p (rx line-start "Cost:") line))
                      lines)
      (p/add-error check file nil
                   "needs a `Cost:' line in Consequences"))))

(defun p/adr-check-date (check file lines)
  "Report a Nygard record in FILE without a `Date:' line."
  (unless (seq-find (lambda (line)
                      (string-match-p
                       (rx line-start "date:" (+ blank)
                           (= 4 digit) "-" (= 2 digit) "-" (= 2 digit))
                       (downcase line)))
                    lines)
    (p/add-error check file nil "needs a `Date: YYYY-MM-DD' line")))

(defun p/adr-check-status-word (check file line word place)
  "Report WORD found at LINE: unknown, or contradicting PLACE."
  (cond
   ((not (member word p/adr-statuses))
    (p/add-error check file line
                 (format "status `%s' is not one of %s"
                         word (string-join p/adr-statuses ", "))))
   ((and (eq place 'superseded) (not (string= word "superseded")))
    (p/add-error check file line
                 (concat "a record in superseded/ must say superseded, "
                         "not amended: an amended record is still in force")))
   ((and (eq place 'top) (string= word "superseded"))
    (p/add-error check file line
                 "a superseded record belongs in superseded/"))))

(defun p/adr-check-front-matter (check file lines number end place)
  "Check the front matter of FILE, ending at END, against NUMBER and PLACE."
  (let* ((pairs (p/adr-front-matter lines end))
         (title (cdr (assq 'title pairs)))
         (status (cdr (assq 'status pairs)))
         (summary (cdr (assq 'summary pairs)))
         (date (or (cdr (assq 'date pairs))
                   (cdr (assq 'decided-on pairs)))))
    (cond
     ((null title)
      (p/add-error check file nil "front matter has no `title'"))
     ((not (string-match (rx bos "ADR-" (group (+ digit)) ":") title))
      (p/add-error check file nil "`title' must read `ADR-NNNN: Title'"))
     ((/= (string-to-number (match-string 1 title))
          (string-to-number number))
      (p/add-error check file nil
                   (format "`title' says %s but the file name says %s"
                           (match-string 1 title) number))))
    (cond
     ((null status)
      (p/add-error check file nil "front matter has no `status'"))
     (t
      (p/adr-check-status-word check file nil
                               (downcase (string-trim status)) place)))
    (unless (and summary (not (string-empty-p summary)))
      (p/add-error check file nil "front matter has no `summary'"))
    (unless date
      (p/add-error check file nil
                   "front matter has no `date' (or `decided-on')"))))

(defun p/adr-check-file (check file place)
  "Check one record FILE, living at PLACE."
  (let* ((name (file-name-nondirectory file))
         (lines (p/file-lines file))
         (end (p/adr-front-matter-end lines))
         (number (and (string-match p/adr-name-rx name)
                      (match-string 1 name))))
    (cond
     ((member name p/adr-generated-names) nil)
     ((string-prefix-p "0000-" name) nil)
     ((null number)
      (p/add-error check file nil
                   (format "a record is named NNNN-kebab-title.md in %s/, not %s"
                           p/adr-dir-name name)))
     (t
      (if end
          (p/adr-check-front-matter check file lines number end place)
        (p/adr-check-title check file lines number)
        (p/adr-check-date check file lines)
        (let ((status (p/adr-section-value lines "Status")))
          (cond
           ((null status)
            (p/add-error check file nil "missing a `## Status' section"))
           ((string-empty-p (car status))
            (p/add-error check file (cdr status) "`## Status' has no value"))
           (t
            (p/adr-check-status-word
             check file (cdr status)
             (downcase (car (split-string (car status) "[^a-zA-Z]+" t)))
             place)))))
      (p/adr-check-sections check file lines)))))

(defconst p/adr-wrong-dirs
  '("doc/adr" "docs/adr" "docs/adrs" "adr")
  "Directories that hold records somewhere the index does not read.")

(p/defcheck-global adr-format :scope "Markdown: the decision directory"
  "Every decision record has a number, a status and the argued sections."
  (let* ((dir (p/adr-dir))
         (root (p/repo-root))
         (entries (p/adr-files)))
    (dolist (wrong p/adr-wrong-dirs)
      (let ((other (expand-file-name wrong root)))
        (when (file-directory-p other)
          (p/add-error check other nil
                       (format "records live in %s/, not in %s/"
                               p/adr-dir-name wrong)))))
    (when dir
      (dolist (entry entries)
        (p/adr-check-file check (car entry) (cdr entry)))
      ;; Two records may not share a number: the number is the reference a
      ;; later record uses when it supersedes one.
      (let ((seen (make-hash-table :test #'equal)))
        (dolist (entry entries)
          (let* ((name (file-name-nondirectory (car entry)))
                 (number (and (string-match p/adr-name-rx name)
                              (string-to-number (match-string 1 name)))))
            (when number
              (if (gethash number seen)
                  (p/add-error check (car entry) nil
                               (format "number %d is already used by %s"
                                       number (gethash number seen)))
                (puthash number (file-relative-name (car entry) root) seen)))))))))
