;;; testcover-audit-main-test.el --- Tests for testcover-audit main module -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for the main entry point of testcover-audit.

;;; Code:

(require 'ert)
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
          (let ((testcover-audit--loaded-files
                 `((,(file-truename file) . ((fixture-function . [edebug-unknown
                                                                  testcover-1value
                                                                  edebug-ok-coverage
                                                                  edebug-ok-coverage]))))))
            (testcover-audit--refresh-mode-line))
          (should (string-match-p "PCTcov" (prin1-to-string mode-line-format)))
          (should (string-match-p "75%" (prin1-to-string mode-line-format))))
      (kill-buffer buffer)
      (delete-file file))))

(provide 'testcover-audit-main-test)
;;; testcover-audit-main-test.el ends here
