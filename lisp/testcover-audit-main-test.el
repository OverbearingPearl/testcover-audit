;;; testcover-audit-main-test.el --- Tests for testcover-audit main module -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for the main entry point of testcover-audit.

;;; Code:

(require 'ert)
(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name))))
(require 'testcover-audit)

(ert-deftest testcover-audit-mode-test ()
  "Test that minor mode toggles correctly."
  ;; TODO: Implement mode test.
  )

(provide 'testcover-audit-main-test)
;;; testcover-audit-main-test.el ends here
