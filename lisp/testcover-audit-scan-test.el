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

(provide 'testcover-audit-scan-test)
;;; testcover-audit-scan-test.el ends here
