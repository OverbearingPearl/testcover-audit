;;; testcover-audit-export-test.el --- Tests for testcover-audit-export -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for Org/JSON export and CI checks.

;;; Code:

(require 'ert)
(require 'json)
(require 'testcover-audit-export)

(ert-deftest testcover-audit-export-test--collected-data ()
  "Test exports aggregate collected coverage vectors."
  (let ((testcover-audit--loaded-files
         '(("a.el" . ((a-function . [edebug-unknown testcover-1value
                                       edebug-ok-coverage edebug-ok-coverage])))
           ("b.el" . ((b-function . [edebug-unknown edebug-unknown
                                     testcover-1value testcover-1value]))))))
    (let ((tmp (make-temp-file "tca-json-collected" nil ".json")))
      (unwind-protect
          (progn
            (testcover-audit-export--export-json tmp)
            (with-temp-buffer
              (insert-file-contents tmp)
              (let ((parsed (json-parse-string (buffer-string))))
                (should (= (gethash "total" parsed) 8))
                (should (= (gethash "covered" parsed) 2))
                (should (= (gethash "onevalue" parsed) 3))
                (should (= (gethash "uncovered" parsed) 3))
                (should (= (gethash "percent" parsed) 63)))))
        (delete-file tmp)))))

(ert-deftest testcover-audit-export-test--no-data ()
  "Test that exporting without coverage data fails."
  (let ((testcover-audit--loaded-files nil)
        (tmp (make-temp-file "tca-json-no-data" nil ".json")))
    (unwind-protect
        (should-error (testcover-audit-export--export-json tmp)
                      :type 'user-error)
      (delete-file tmp))))

(ert-deftest testcover-audit-export-test--org ()
  "Test Org export produces expected output."
  (let ((tmp (make-temp-file "tca-org-test" nil ".org"))
        (testcover-audit--loaded-files
         '(("fixture.el" . ((fixture-function . [edebug-unknown
                                                  testcover-1value
                                                  edebug-ok-coverage
                                                  edebug-ok-coverage]))))))
    (unwind-protect
        (progn
          (testcover-audit-export--export-org tmp)
          (with-temp-buffer
            (insert-file-contents tmp)
            (should (string-match-p "Coverage Report" (buffer-string)))))
      (delete-file tmp))))

(ert-deftest testcover-audit-export-test--json ()
  "Test JSON export produces valid JSON."
  (let ((tmp (make-temp-file "tca-json-test" nil ".json"))
        (testcover-audit--loaded-files
         '(("fixture.el"
            . ((fixture-function
                . [edebug-unknown testcover-1value
                   edebug-ok-coverage edebug-ok-coverage]))))))
    (unwind-protect
        (progn
          (testcover-audit-export--export-json tmp)
          (with-temp-buffer
            (insert-file-contents tmp)
            (let* ((parsed (json-parse-string (buffer-string)))
                   (percent (gethash "percent" parsed))
                   (total (gethash "total" parsed)))
              (should (numberp percent))
              (should (numberp total))
              (should (= total 4))
              (should (= percent 75)))))
      (delete-file tmp))))

(provide 'testcover-audit-export-test)
;;; testcover-audit-export-test.el ends here
