;;; pearl-testcover-main-test.el --- Tests for pearl-testcover main module -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for the main entry point of pearl-testcover.

;;; Code:

(require 'ert)
(add-to-list 'load-path (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name))))
(require 'pearl-testcover)

(ert-deftest pearl-testcover-mode-test ()
  "Test that minor mode toggles correctly."
  ;; TODO: Implement mode test.
  )

(provide 'pearl-testcover-main-test)
;;; pearl-testcover-main-test.el ends here
