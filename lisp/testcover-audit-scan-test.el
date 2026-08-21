;;; testcover-audit-scan-test.el --- Tests for testcover-audit-scan -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for directory scanning and dependency ordering.

;;; Code:

(require 'ert)
(require 'seq)
(require 'edebug)
(require 'testcover-audit-scan)

(ert-deftest testcover-audit-scan-test--dependency-order ()
  "Test dependency ordering of files."
  (let ((files '("b.el" "a.el")))
    (should (equal (testcover-audit-scan--dependency-order files)
                   '("a.el" "b.el")))))

(ert-deftest testcover-audit-scan-test--collects-coverage ()
  "Scan-directory collects vectors from testcover-instrumented definitions."
  (let* ((dir (make-temp-file "tca-scan-collect" t))
         (file (expand-file-name "foo.el" dir))
         (symbol (make-symbol "tca-scan-fixture-function")))
    (with-temp-file file (insert ";; dummy"))
    (let ((buf (find-file-noselect file)))
      (unwind-protect
          (progn
            (with-current-buffer buf
              (setq-local edebug-form-data
                          (list (edebug--make-form-data-entry
                                 symbol
                                 (copy-marker (point-min))
                                 (copy-marker (point-max))))))
            (put symbol 'edebug-behavior 'testcover)
            (put symbol 'edebug-coverage
                 [edebug-unknown testcover-1value
                  edebug-ok-coverage edebug-ok-coverage])
            (let ((testcover-audit-exclude-files nil))
              (testcover-audit-scan--scan-directory dir))
            (let ((entry (assoc (file-truename file) testcover-audit--loaded-files)))
              (should entry)
              (should (equal (cdr entry)
                             `((,symbol . [edebug-unknown testcover-1value
                                           edebug-ok-coverage edebug-ok-coverage]))))))
        (cl-remprop symbol 'edebug-behavior)
        (cl-remprop symbol 'edebug-coverage)
        (kill-buffer buf)
        (delete-directory dir t)))))

(ert-deftest testcover-audit-scan-test--does-not-instrument ()
  "Scan-directory does not instrument files lacking coverage."
  (let* ((dir (make-temp-file "tca-scan-no-instrument" t))
         (file (expand-file-name "bar.el" dir))
         (start-calls 0))
    (with-temp-file file (insert ";; dummy"))
    (let ((buf (find-file-noselect file)))
      (unwind-protect
          (progn
            (cl-letf (((symbol-function 'testcover-start)
                       (lambda (&rest _) (cl-incf start-calls))))
              (let ((testcover-audit-exclude-files nil))
                (testcover-audit-scan--scan-directory dir)))
            (should (= start-calls 0))
            (should-not (assoc (file-truename file) testcover-audit--loaded-files)))
        (kill-buffer buf)
        (delete-directory dir t)))))

(ert-deftest testcover-audit-scan-test--reports-skipped-files ()
  "Scan reports files skipped because they have no visiting buffer."
  (let* ((dir (make-temp-file "tca-scan-debug" t))
         (file (expand-file-name "missing-buffer.el" dir))
         (messages nil))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert ";; dummy"))
          (let ((testcover-audit-exclude-files nil))
            (cl-letf (((symbol-function 'message)
                       (lambda (format-string &rest args)
                         (push (apply #'format format-string args) messages))))
              (testcover-audit-scan--scan-directory dir)))
          (should
           (seq-some
            (lambda (message)
              (string-match-p "Skipped 1 files: 1 not open" message))
            messages)))
      (delete-directory dir t))))

(ert-deftest testcover-audit-scan-test--definition-line-stats ()
  "Definition-line-stats groups coverage by source line."
  (let* ((dir (make-temp-file "tca-line" t))
         (file (expand-file-name "foo.el" dir))
         (symbol (make-symbol "tca-line-fn"))
         (buf nil))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "(defun tca-line-fn ()\n"
                    "  (let ((x 1))\n"
                    "    (message \"%d\" x)\n"
                    "    nil))\n"))
          (setq buf (find-file-noselect file))
          (with-current-buffer buf
            ;; Simulate edebug's position data: (def-mark unused points).
            (put symbol 'edebug
                 (list (copy-marker (point-min))
                       nil
                       (vector 0 22 37)))
            (put symbol 'edebug-behavior 'testcover)
            (put symbol 'edebug-coverage
                 [edebug-unknown edebug-ok-coverage edebug-ok-coverage])
            (let ((line-stats (testcover-audit-scan--definition-line-stats
                               symbol
                               [edebug-unknown
                                edebug-ok-coverage
                                edebug-ok-coverage])))
              (should (equal (mapcar #'car line-stats) '(1 2 3)))
              (should (= (plist-get (cdr (nth 0 line-stats)) :uncovered) 1))
              (should (= (plist-get (cdr (nth 1 line-stats)) :covered) 1))
              (should (= (plist-get (cdr (nth 2 line-stats)) :total) 1)))))
      (cl-remprop symbol 'edebug)
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (delete-directory dir t))))

(ert-deftest testcover-audit-scan-test--coverage-vector-p ()
  (should
   (testcover-audit-scan--coverage-vector-p
    [edebug-unknown testcover-1value edebug-ok-coverage noreturn]))
  (should (testcover-audit-scan--coverage-vector-p [0 1 2 3]))
  (should
   (testcover-audit-scan--coverage-vector-p
    [edebug-unknown "one-result" fixture-symbol
     (noreturn . 12) nil]))
  (should-not (testcover-audit-scan--coverage-vector-p [])))

(ert-deftest testcover-audit-scan-test--ignores-non-testcover-edebug ()
  "Scan ignores Edebug coverage not owned by testcover."
  (let* ((dir (make-temp-file "tca-scan-non-testcover" t))
         (file (expand-file-name "fixture.el" dir))
         (symbol (make-symbol "tca-non-testcover-function"))
         (buf nil))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "(defun fixture () nil)\n"))
          (setq buf (find-file-noselect file))
          (with-current-buffer buf
            (setq-local edebug-form-data
                        (list (edebug--make-form-data-entry
                               symbol
                               (copy-marker (point-min))
                               (copy-marker (point-max))))))
          (put symbol 'edebug-behavior 'edebug)
          (put symbol 'edebug-coverage [edebug-ok-coverage])
          (let ((testcover-audit-exclude-files nil))
            (testcover-audit-scan--scan-directory dir))
          (should-not (assoc (file-truename file)
                             testcover-audit--loaded-files)))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf)
        (kill-buffer buf))
      (delete-directory dir t))))

(ert-deftest testcover-audit-scan-test--buffer-function-stats-live ()
  "Buffer-function-stats reads live coverage without touching loaded-files."
  (let* ((dir (make-temp-file "tca-scan-live-fn" t))
         (file (expand-file-name "foo.el" dir))
         (symbol (make-symbol "tca-live-fn"))
         (buf nil))
    (unwind-protect
        (progn
          (with-temp-file file (insert ";; dummy"))
          (setq buf (find-file-noselect file))
          (with-current-buffer buf
            (setq-local edebug-form-data
                        (list (edebug--make-form-data-entry
                               symbol
                               (copy-marker (point-min))
                               (copy-marker (point-max))))))
          (put symbol 'edebug-behavior 'testcover)
          (put symbol 'edebug-coverage
               [edebug-unknown testcover-1value
                edebug-ok-coverage edebug-ok-coverage])
          (let ((rows (testcover-audit-scan--buffer-function-stats file)))
            (should (= (length rows) 1))
            (should (string= (plist-get (car rows) :name)
                             (symbol-name symbol)))
            (should (= (plist-get (car rows) :percent) 75)))
          (should-not (assoc (file-truename file)
                             testcover-audit--loaded-files)))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf)
        (kill-buffer buf))
      (delete-directory dir t))))

(ert-deftest testcover-audit-scan-test--buffer-stats-live ()
  "Buffer-stats aggregates live coverage from the visiting buffer."
  (let* ((dir (make-temp-file "tca-scan-live-stats" t))
         (file (expand-file-name "foo.el" dir))
         (symbol (make-symbol "tca-live-stats-fn"))
         (buf nil))
    (unwind-protect
        (progn
          (with-temp-file file (insert ";; dummy"))
          (setq buf (find-file-noselect file))
          (with-current-buffer buf
            (setq-local edebug-form-data
                        (list (edebug--make-form-data-entry
                               symbol
                               (copy-marker (point-min))
                               (copy-marker (point-max))))))
          (put symbol 'edebug-behavior 'testcover)
          (put symbol 'edebug-coverage
               [edebug-unknown testcover-1value
                edebug-ok-coverage edebug-ok-coverage])
          (let ((stats (testcover-audit-scan--buffer-stats file)))
            (should stats)
            (should (= (plist-get stats :total) 4))
            (should (= (plist-get stats :covered) 2))
            (should (= (plist-get stats :onevalue) 1))
            (should (= (plist-get stats :uncovered) 1))
            (should (= (plist-get stats :percent) 75))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf)
        (kill-buffer buf))
      (delete-directory dir t))))

(ert-deftest testcover-audit-scan-test--instrument-directory ()
  "Instrument-directory instruments source files but skips test/excluded files."
  (let* ((dir (make-temp-file "tca-instr" t))
         (src1 (expand-file-name "src1.el" dir))
         (src2 (expand-file-name "src2.el" dir))
         (test-file (expand-file-name "foo-test.el" dir))
         (calls nil))
    (unwind-protect
        (progn
          (with-temp-file src1 (insert ";; dummy"))
          (with-temp-file src2 (insert ";; dummy"))
          (with-temp-file test-file (insert ";; dummy"))
          (cl-letf (((symbol-function 'testcover-start)
                     (lambda (file) (push file calls))))
            (let ((testcover-audit-exclude-files '("^\\."))
                  (testcover-audit-test-file-regexp "\\(?:\\`\\|[-_]\\)test\\.el\\'"))
              (testcover-audit-scan--instrument-directory dir)))
          (should (= (length calls) 2))
          (should (seq-some (lambda (c) (string-match-p "src1.el" c)) calls))
          (should (seq-some (lambda (c) (string-match-p "src2.el" c)) calls))
          (should-not (seq-some (lambda (c) (string-match-p "foo-test.el" c)) calls)))
      (delete-directory dir t))))

(ert-deftest testcover-audit-scan-test--project-report ()
  "Project-report scans root and generates batch report."
  (let* ((dir (make-temp-file "tca-proj" t))
         (git-dir (expand-file-name ".git" dir)))
    (unwind-protect
        (progn
          (make-directory git-dir)
          (let ((default-directory dir)
                (scan-called nil)
                (report-called nil))
            (cl-letf (((symbol-function 'testcover-audit-scan--scan-directory)
                       (lambda (_) (setq scan-called t)))
                      ((symbol-function 'testcover-audit-report--batch-report)
                       (lambda () (setq report-called t))))
              (testcover-audit-scan--project-report))
            (should scan-called)
            (should report-called)))
      (delete-directory dir t))))

(provide 'testcover-audit-scan-test)
;;; testcover-audit-scan-test.el ends here
