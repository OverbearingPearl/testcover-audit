;;; testcover-audit-core-test.el --- Tests for testcover-audit-core -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for the pure statistics engine.

;;; Code:

(require 'ert)
(require 'testcover-audit-core)

(ert-deftest testcover-audit--collect-stats-test ()
  "Test parsing of an edebug-coverage vector."
  ;; TODO: Implement test with sample vector.
  )

(ert-deftest testcover-audit--percent-test ()
  "Test percentage calculation."
  (should (= (testcover-audit--percent 40 80) 50))
  (should (= (testcover-audit--percent 0 0) 100)))

(provide 'testcover-audit-core-test)
;;; testcover-audit-core-test.el ends here
