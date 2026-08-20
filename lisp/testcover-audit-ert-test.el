;;; testcover-audit-ert-test.el --- Tests for testcover-audit-ert -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for ERT integration.

;;; Code:

(require 'ert)
(require 'testcover-audit-ert)

(ert-deftest testcover-audit-ert-test--hook ()
  "Test the package hook runs when the ERT hook callback is invoked."
  (let (called)
    (let ((testcover-audit-ert-after-run-hook
           (list (lambda () (setq called t)))))
      (testcover-audit-ert--after-run)
      (should called))))

(ert-deftest testcover-audit-ert-test--mode ()
  "Test that ERT mode toggles the coverage advice correctly."
  (testcover-audit-ert-mode 1)
  (should (advice-member-p #'testcover-audit-ert--after-run 'ert-run-tests-batch))
  (testcover-audit-ert-mode -1)
  (should-not (advice-member-p #'testcover-audit-ert--after-run 'ert-run-tests-batch)))

(ert-deftest testcover-audit-ert-test--after-run-no-auto-show ()
  "After-run runs hooks but skips scan/report when auto-show is nil."
  (let ((scan-called nil)
        (report-called nil))
    (let ((testcover-audit-auto-show-report nil)
          (testcover-audit-ert-scan-directory nil))
      (cl-letf (((symbol-function 'testcover-audit-scan--scan-directory)
                 (lambda (_) (setq scan-called t)))
                ((symbol-function 'testcover-audit-report--batch-report)
                 (lambda () (setq report-called t))))
        (testcover-audit-ert--after-run))
      (should-not scan-called)
      (should-not report-called))))

(ert-deftest testcover-audit-ert-test--after-run-auto-show-no-scan-dir ()
  "After-run runs report but skips scan when scan-directory is nil."
  (let ((scan-called nil)
        (report-called nil))
    (let ((testcover-audit-auto-show-report t)
          (testcover-audit-ert-scan-directory nil))
      (cl-letf (((symbol-function 'testcover-audit-scan--scan-directory)
                 (lambda (_) (setq scan-called t)))
                ((symbol-function 'testcover-audit-report--batch-report)
                 (lambda () (setq report-called t))))
        (testcover-audit-ert--after-run))
      (should-not scan-called)
      (should report-called))))

(ert-deftest testcover-audit-ert-test--after-run-auto-show-with-scan-dir ()
  "After-run runs both scan and report when auto-show and scan-directory are set."
  (let ((scan-called nil)
        (report-called nil))
    (let ((testcover-audit-auto-show-report t)
          (testcover-audit-ert-scan-directory "/tmp/dir"))
      (cl-letf (((symbol-function 'testcover-audit-scan--scan-directory)
                 (lambda (_) (setq scan-called t)))
                ((symbol-function 'testcover-audit-report--batch-report)
                 (lambda () (setq report-called t))))
        (testcover-audit-ert--after-run))
      (should scan-called)
      (should report-called))))

(provide 'testcover-audit-ert-test)
;;; testcover-audit-ert-test.el ends here
