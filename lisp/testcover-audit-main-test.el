;;; testcover-audit-main-test.el --- Tests for testcover-audit main module -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for the main entry point of testcover-audit.

;;; Code:

(require 'ert)
(require 'seq)
(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name))))
(require 'testcover-audit)

(ert-deftest testcover-audit-main-test--mode ()
  "Test that minor mode toggles correctly."
  (let ((buffer (generate-new-buffer "*tca-test*")))
    (unwind-protect
        (with-current-buffer buffer
          (testcover-audit-mode 1)
          (should testcover-audit-mode)
          (testcover-audit-mode -1)
          (should-not testcover-audit-mode))
      (kill-buffer buffer))))

(ert-deftest testcover-audit-main-test--refresh-mode-line ()
  "Test that refresh-mode-line adds coverage information."
  (let* ((file (make-temp-file "tca-ml-test" nil ".el"))
         (buffer (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buffer
          (let ((testcover-audit-core--loaded-files
                 `((,(file-truename file) . ((fixture-function . [edebug-unknown
                                                                  testcover-1value
                                                                  edebug-ok-coverage
                                                                  edebug-ok-coverage]))))))
            (testcover-audit--refresh-mode-line))
          (should (string-match-p "PCTcov" (prin1-to-string mode-line-format)))
          (should (string-match-p "75%" (prin1-to-string mode-line-format))))
      (kill-buffer buffer)
      (delete-file file))))

(ert-deftest testcover-audit-main-test--export-org-wrapper ()
  "Test export-org wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-export--export-org)
               (lambda (file) (setq called file))))
      (testcover-audit-export-org "/tmp/test.org")
      (should (string= called "/tmp/test.org")))))

(ert-deftest testcover-audit-main-test--export-json-wrapper ()
  "Test export-json wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-export--export-json)
               (lambda (file) (setq called file))))
      (testcover-audit-export-json "/tmp/test.json")
      (should (string= called "/tmp/test.json")))))

(ert-deftest testcover-audit-main-test--ci-check-wrapper ()
  "Test ci-check wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-export--ci-check)
               (lambda () (setq called t))))
      (testcover-audit-ci-check)
      (should called))))

(ert-deftest testcover-audit-main-test--show-stats-wrapper ()
  "Test show-stats wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-report--show-stats)
               (lambda () (setq called t))))
      (testcover-audit-show-stats)
      (should called))))

(ert-deftest testcover-audit-main-test--show-all-stats-wrapper ()
  "Test show-all-stats wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-report--show-all-stats)
               (lambda () (setq called t))))
      (testcover-audit-show-all-stats)
      (should called))))

(ert-deftest testcover-audit-main-test--show-function-stats-wrapper ()
  "Test show-function-stats wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-report--show-function-stats)
               (lambda () (setq called t))))
      (testcover-audit-show-function-stats)
      (should called))))

(ert-deftest testcover-audit-main-test--batch-report-wrapper ()
  "Test batch-report wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-report--batch-report)
               (lambda () (setq called t))))
      (testcover-audit-batch-report)
      (should called))))

(ert-deftest testcover-audit-main-test--instrument-directory-wrapper ()
  "Test instrument-directory wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-scan--instrument-directory)
               (lambda (dir) (setq called dir))))
      (testcover-audit-instrument-directory "/tmp/src")
      (should (string= called "/tmp/src")))))

(ert-deftest testcover-audit-main-test--scan-directory-wrapper ()
  "Test scan-directory wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-scan--scan-directory)
               (lambda (dir) (setq called dir))))
      (testcover-audit-scan-directory "/tmp/src")
      (should (string= called "/tmp/src")))))

(ert-deftest testcover-audit-main-test--project-report-wrapper ()
  "Test project-report wrapper calls underlying function."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-report--project-report)
               (lambda () (setq called t))))
      (testcover-audit-project-report)
      (should called))))

(ert-deftest testcover-audit-main-test--reload-modules ()
  "Test reload-modules stubs load-file/unload-feature and reports success."
  (let (msg-captured)
    (cl-letf (((symbol-function 'unload-feature) (lambda (&rest _) nil))
              ((symbol-function 'load-file) (lambda (&rest _) nil))
              ((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) msg-captured))))
      (testcover-audit--reload-modules)
      (should (seq-some (lambda (m) (string-match-p "reloaded" m)) msg-captured)))))

(provide 'testcover-audit-main-test)
;;; testcover-audit-main-test.el ends here
