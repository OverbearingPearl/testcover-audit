;;; testcover-audit-report-test.el --- Tests for testcover-audit-report -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for report rendering.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'testcover-audit-report)

(ert-deftest testcover-audit-report-test--format-table ()
  "Test table formatting with sample rows."
  (let ((table (testcover-audit-report--format-table '(("a" 1) ("bb" 22)))))
    (should (string-match-p "a" table))
    (should (string-match-p "bb" table))
    (should (string-match-p "22" table))))

(ert-deftest testcover-audit-report-test--face-for-percent ()
  "Test color threshold face selection."
  (let ((testcover-audit-green-threshold 80)
        (testcover-audit-yellow-threshold 50))
    (should (eq (testcover-audit-report--face-for-percent 90) 'success))
    (should (eq (testcover-audit-report--face-for-percent 60) 'warning))
    (should (eq (testcover-audit-report--face-for-percent 10) 'error))))

(ert-deftest testcover-audit-report-test--batch-aggregates ()
  "Test batch reporting converts vectors to stats before aggregation."
  (let ((testcover-audit--loaded-files
         (list (cons (file-truename (expand-file-name "a.el"))
                     (list (cons 'a-function [edebug-unknown testcover-1value
                                              edebug-ok-coverage edebug-ok-coverage])))
               (cons (file-truename (expand-file-name "b.el"))
                     (list (cons 'b-function [edebug-unknown edebug-unknown
                                              testcover-1value testcover-1value]))))))
    (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
      (testcover-audit-report--batch-report))
    (with-current-buffer "*Testcover Batch Report*"
      (should (string-match-p "63" (buffer-string))))))

(ert-deftest testcover-audit-report-test--show-stats-no-data ()
  "Message when no collected data exists."
  (let ((buf (generate-new-buffer "*tca-msg-test*")))
    (unwind-protect
        (with-current-buffer buf
          (let (messages)
            (cl-letf (((symbol-function 'message)
                       (lambda (format-string &rest args)
                         (push (apply #'format format-string args) messages))))
              (testcover-audit-report--show-stats))
            (should (string-match-p "No coverage data" (car messages)))))
      (kill-buffer buf))))

(ert-deftest testcover-audit-report-test--stats-for-file ()
  "Helper returns nil when no data is collected."
  (let ((buf (generate-new-buffer "*tca-stats-file*")))
    (unwind-protect
        (with-current-buffer buf
          (setq testcover-audit--loaded-files nil)
          (should (null (testcover-audit-report--stats-for-file "no-such-file.el"))))
      (kill-buffer buf))))

(ert-deftest testcover-audit-report-test--show-stats-with-coverage ()
  "Message shows coverage from the collected function snapshot."
  (let* ((file (make-temp-file "tca-msg-cov" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit--loaded-files
                 `((,(file-truename file) . ((fixture-function . [edebug-unknown
                                                                  testcover-1value
                                                                  edebug-ok-coverage
                                                                  edebug-ok-coverage])))))
                (messages nil))
            (cl-letf (((symbol-function 'message)
                       (lambda (format-string &rest args)
                         (push (apply #'format format-string args) messages))))
              (testcover-audit-report--show-stats))
            (should (equal messages '("Coverage: 75% (2/4)")))))
      (kill-buffer buf))))

(ert-deftest testcover-audit-report-test--show-all-stats-with-data ()
  "Test show-all-stats displays buffer with coverage percentage."
  (let* ((file (make-temp-file "tca-show-all" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit--loaded-files
                 `((,(file-truename file) . ((fixture-fn . [edebug-unknown
                                                            testcover-1value
                                                            edebug-ok-coverage
                                                            edebug-ok-coverage])))))
                (display-buffer-called nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-all-stats))
            (should display-buffer-called)
            (with-current-buffer "*Testcover Audit Report*"
              (should (string-match-p "Coverage %" (buffer-string)))
              (should (string-match-p "75" (buffer-string))))))
      (kill-buffer buf)
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-function-stats-mixed ()
  "Test show-function-stats lists functions with varying coverage."
  (let* ((file (make-temp-file "tca-func-stats" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit--loaded-files
                 (list (cons (file-truename file)
                             (list (cons 'good-fn [edebug-ok-coverage edebug-ok-coverage])
                                   (cons 'bad-fn [edebug-unknown edebug-unknown])))))
                (display-buffer-called nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-function-stats))
            (should display-buffer-called)
            (with-current-buffer "*Testcover Function Report*"
              (should (string-match-p "good-fn" (buffer-string)))
              (should (string-match-p "bad-fn" (buffer-string)))
              (should (string-match-p "0%" (buffer-string))))))
      (kill-buffer buf)
      (delete-file file))))

(ert-deftest testcover-audit-report-test--batch-report-with-low-funcs ()
  "Test batch-report includes function-level breakdown for low coverage."
  (let ((testcover-audit--loaded-files
         (list (cons (file-truename (expand-file-name "a.el" temporary-file-directory))
                     (list (cons 'high-fn [edebug-ok-coverage edebug-ok-coverage])
                           (cons 'low-fn [edebug-unknown edebug-unknown]))))))
    (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
      (testcover-audit-report--batch-report))
    (with-current-buffer "*Testcover Batch Report*"
      (should (string-match-p "Function-level breakdown" (buffer-string)))
      (should (string-match-p "low-fn" (buffer-string))))))

(ert-deftest testcover-audit-report-test--batch-report-no-data-msg ()
  "Test batch-report shows message when no data is collected."
  (let ((testcover-audit--loaded-files nil)
        (msg-captured nil))
    (cl-letf (((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) msg-captured))))
      (testcover-audit-report--batch-report))
    (should (seq-some (lambda (m) (string-match-p "No coverage data collected" m)) msg-captured))))

(provide 'testcover-audit-report-test)
;;; testcover-audit-report-test.el ends here
