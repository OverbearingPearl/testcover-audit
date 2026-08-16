;;; pearl-testcover-core-test.el --- Tests for pearl-testcover-core -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for the pure statistics engine.

;;; Code:

(require 'ert)
(require 'pearl-testcover-core)

(ert-deftest pearl-testcover--collect-stats-test ()
  "Test parsing of an edebug-coverage vector."
  ;; TODO: Implement test with sample vector.
  )

(ert-deftest pearl-testcover--percent-test ()
  "Test percentage calculation."
  (should (= (pearl-testcover--percent 40 80) 50))
  (should (= (pearl-testcover--percent 0 0) 100)))

(provide 'pearl-testcover-core-test)
;;; pearl-testcover-core-test.el ends here
