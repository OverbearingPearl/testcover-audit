;;; 18-doc-links.el --- relative links and anchors in Markdown resolve -*- lexical-binding: t; -*-

;;; Commentary:

;; A design document is the only place some claims are written down, so a
;; broken link there loses an argument rather than a page.  Two things rot
;; quietly: a relative path after a file moved, and an anchor after a heading
;; was reworded.  Both are checked here.
;;
;; Anchors follow the renderer's rule: lower-case the heading, drop
;; everything that is not a letter, digit, hyphen or space, then turn spaces
;; into hyphens.  Inline code and emphasis markers are dropped first, so
;; the heading "3. Why the session lives in the core" gets the anchor
;; "#3-why-the-session-lives-in-the-core".

;;; Code:

(require 'seq)

(defconst p/doc-link-rx
  "](\\([^)]*\\))"
  "Regexp capturing the target of a Markdown link.")

(defun p/md-files (files)
  "Return the Markdown files among FILES."
  (seq-filter (lambda (file) (string-suffix-p ".md" file)) files))

(defun p/heading-anchor (line)
  "Return the anchor a Markdown heading LINE produces, or nil if not a heading."
  (when (string-match (rx line-start (+ "#") (+ blank) (group (+ nonl)) line-end)
                      line)
    (let ((text (match-string 1 line)))
      (setq text (replace-regexp-in-string "`\\|\\(\\*\\*\\)" "" text))
      (setq text (downcase text))
      (setq text (replace-regexp-in-string "[^a-z0-9 -]" "" text))
      (replace-regexp-in-string " " "-" text))))

(defun p/md-anchors (file)
  "Return the set of anchors FILE defines."
  (let ((anchors nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((anchor (p/heading-anchor (buffer-substring-no-properties
                                         (line-beginning-position)
                                         (line-end-position)))))
          (when anchor (push anchor anchors)))
        (forward-line 1)))
    anchors))

(defconst p/img-src-rx
  "<img[^>]+src=\"\\([^\"]+\\)\""
  "Regexp capturing the source of an HTML image in Markdown.")

(defun p/link-targets (file)
  "Return the raw link and image targets found in FILE."
  (let ((targets nil))
    (with-temp-buffer
      (insert-file-contents file)
      (dolist (rx (list p/doc-link-rx p/img-src-rx))
        (goto-char (point-min))
        (while (re-search-forward rx nil t)
          (push (match-string 1) targets))))
    (nreverse targets)))

(defun p/external-link-p (target)
  "Return non-nil when TARGET is not resolved inside this repository."
  (or (string-match-p (rx bos (+ alnum) ":") target)
      (string-prefix-p "/" target)))

(defun p/check-one-link (check file target root)
  "Report problems with TARGET, found in FILE, relative to ROOT."
  (let* ((hash (string-match-p "#" target))
         (path (if hash (substring target 0 hash) target))
         (anchor (if hash (substring target (1+ hash)) nil))
         (base (file-name-directory file))
         (full (if (string= path "") file (expand-file-name path base))))
    (cond
     ((and (string= path "") (null anchor))
      (p/add-error check (file-relative-name file root) nil
                   (format "empty link target `%s'" target)))
     ((not (string= path ""))
      (unless (file-exists-p full)
        (p/add-error check (file-relative-name file root) nil
                     (format "link target does not exist: %s" target)))
      (when (and anchor (string-suffix-p ".md" full) (file-exists-p full))
        (unless (member anchor (p/md-anchors full))
          (p/add-error check (file-relative-name file root) nil
                       (format "anchor not found: %s" target)))))
     ((and anchor (not (member anchor (p/md-anchors file))))
      (p/add-error check (file-relative-name file root) nil
                   (format "anchor not found in this file: %s" target))))))

(p/defcheck-global doc-links :scope "Markdown: docs/ and README.md"
  "Relative links, images and anchors in Markdown resolve."
  (let ((root (p/repo-root)))
    (dolist (rel (p/md-files (p/tracked-files)))
      (let ((full (expand-file-name rel root)))
        (when (file-regular-p full)
          (dolist (target (p/link-targets full))
            (unless (p/external-link-p target)
              (p/check-one-link check full target root))))))))

;;; 18-doc-links.el ends here
