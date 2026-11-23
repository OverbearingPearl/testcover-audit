;;; options-tests.el --- Tests for testcover-audit-options -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for user options.

;;; Code:

(require 'ert)
(require 'testcover-audit-options)

(ert-deftest options-tests--defaults ()
  "Test that default options are meaningful."
  (should (>= testcover-audit-green-threshold 0))
  (should (>= testcover-audit-yellow-threshold 0))
  (should (memq testcover-audit-report-format '(table list)))
  (should (integerp testcover-audit-ci-threshold))
  (should (listp testcover-audit-exclude-files)))

(provide 'options-tests)

;;; options-tests.el ends here
