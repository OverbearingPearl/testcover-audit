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

(provide 'testcover-audit-ert-test)
;;; testcover-audit-ert-test.el ends here
