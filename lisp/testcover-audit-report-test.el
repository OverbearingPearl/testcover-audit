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
         '(("a.el" . ((a-function . [edebug-unknown testcover-1value
                                       edebug-ok-coverage edebug-ok-coverage])))
           ("b.el" . ((b-function . [edebug-unknown edebug-unknown
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

(provide 'testcover-audit-report-test)
;;; testcover-audit-report-test.el ends here
