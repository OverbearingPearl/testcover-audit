;;; testcover-audit-report-test.el --- Tests for testcover-audit-report -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for report rendering.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edebug)
(require 'testcover-audit-report)

(ert-deftest testcover-audit-report-test--format-table ()
  "Test table formatting with sample rows."
  (let ((table (testcover-audit-report--format-table '(("a" 1) ("bb" 22)))))
    (should (string-match-p "a" table))
    (should (string-match-p "bb" table))
    (should (string-match-p "22" table)))
  (let ((table (testcover-audit-report--format-table
                '(("h1" "h2" "h3") ("a" 1 2) ("bbb" 33 44)))))
    (should (string-match-p "h1" table))
    (should (string-match-p "h3" table))
    (should (string-match-p "33" table))
    (should (string-match-p "44" table))))

(ert-deftest testcover-audit-report-test--face-for-percent ()
  "Test color threshold face selection."
  (let ((testcover-audit-green-threshold 80)
        (testcover-audit-yellow-threshold 50))
    (should (eq (testcover-audit-report--face-for-percent 90) 'success))
    (should (eq (testcover-audit-report--face-for-percent 60) 'warning))
    (should (eq (testcover-audit-report--face-for-percent 10) 'error))))

(ert-deftest testcover-audit-report-test--batch-aggregates ()
  "Test batch reporting converts vectors to stats before aggregation."
  (let ((testcover-audit--loaded-files
         (list (cons (file-truename (expand-file-name "a.el"))
                     (list (cons 'a-function [edebug-unknown testcover-1value
                                              edebug-ok-coverage edebug-ok-coverage])))
               (cons (file-truename (expand-file-name "b.el"))
                     (list (cons 'b-function [edebug-unknown edebug-unknown
                                              testcover-1value testcover-1value]))))))
    (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
      (testcover-audit-report--batch-report))
    (with-current-buffer "*Testcover Batch Report*"
      (should (string-match-p "63" (buffer-string))))))

(ert-deftest testcover-audit-report-test--show-stats-no-data ()
  "Message when no collected data exists."
  (let ((buf (generate-new-buffer "*tca-msg-test*")))
    (unwind-protect
        (with-current-buffer buf
          (let (messages)
            (cl-letf (((symbol-function 'message)
                       (lambda (format-string &rest args)
                         (push (apply #'format format-string args) messages))))
              (testcover-audit-report--show-stats))
            (should (string-match-p "No coverage data" (car messages)))))
      (kill-buffer buf))))

(ert-deftest testcover-audit-report-test--stats-for-file ()
  "Helper returns nil when no data is collected."
  (let ((buf (generate-new-buffer "*tca-stats-file*")))
    (unwind-protect
        (with-current-buffer buf
          (setq testcover-audit--loaded-files nil)
          (should (null (testcover-audit-report--stats-for-file "no-such-file.el"))))
      (kill-buffer buf))))

(ert-deftest testcover-audit-report-test--show-stats-with-coverage ()
  "Message shows coverage from the collected function snapshot."
  (let* ((file (make-temp-file "tca-msg-cov" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit--loaded-files
                 `((,(file-truename file) . ((fixture-function . [edebug-unknown
                                                                  testcover-1value
                                                                  edebug-ok-coverage
                                                                  edebug-ok-coverage])))))
                (messages nil))
            (cl-letf (((symbol-function 'message)
                       (lambda (format-string &rest args)
                         (push (apply #'format format-string args) messages))))
              (testcover-audit-report--show-stats))
            (should (equal messages '("Coverage: 75% (2/4)")))))
      (kill-buffer buf))))

(ert-deftest testcover-audit-report-test--show-all-stats-with-data ()
  "Test show-all-stats displays buffer with coverage percentage."
  (let* ((file (make-temp-file "tca-show-all" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit--loaded-files
                 `((,(file-truename file) . ((fixture-fn . [edebug-unknown
                                                            testcover-1value
                                                            edebug-ok-coverage
                                                            edebug-ok-coverage])))))
                (display-buffer-called nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-all-stats))
            (should display-buffer-called)
            (with-current-buffer "*Testcover Audit Report*"
              (should (string-match-p "Testcover Audit Report" (buffer-string)))
              (should (string-match-p "Function-level breakdown" (buffer-string)))
              (should (string-match-p "75" (buffer-string))))))
      (kill-buffer buf)
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-function-stats-line-level ()
  "Show-function-stats shows line breakdown with live position data."
  (let* ((file (make-temp-file "tca-line-report" nil ".el"))
         (symbol (make-symbol "tca-line-report-fn"))
         (buf (find-file-noselect file))
         (display-buffer-called nil))
    (unwind-protect
        (with-current-buffer buf
          (insert "(defun tca-line-report-fn ()\n"
                  "  (let ((x 1))\n"
                  "    (message \"%d\" x)\n"
                  "    nil))\n")
          (setq-local edebug-form-data
                      (list (edebug--make-form-data-entry
                             symbol
                             (copy-marker (point-min))
                             (copy-marker (point-max)))))
          (put symbol 'edebug
               (list (copy-marker (point-min)) nil (vector 0 20 40)))
          (put symbol 'edebug-behavior 'testcover)
          (put symbol 'edebug-coverage
               [edebug-unknown edebug-ok-coverage edebug-ok-coverage])
          (let ((testcover-audit--loaded-files nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-function-stats)))
          (should display-buffer-called)
          (with-current-buffer "*Testcover Function Report*"
            (should (string-match-p "tca-line-report-fn" (buffer-string)))
            (should (string-match-p "Line" (buffer-string)))
            (should (string-match-p "Total" (buffer-string)))
            (should (string-match-p "Uncovered" (buffer-string)))))
      (cl-remprop symbol 'edebug)
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-function-stats-mixed ()
  "Test show-function-stats lists functions with varying coverage."
  (let* ((file (make-temp-file "tca-func-stats" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit--loaded-files
                 (list (cons (file-truename file)
                             (list (cons 'good-fn [edebug-ok-coverage edebug-ok-coverage])
                                   (cons 'bad-fn [edebug-unknown edebug-unknown])))))
                (display-buffer-called nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-function-stats))
            (should display-buffer-called)
            (with-current-buffer "*Testcover Function Report*"
              (should (string-match-p "good-fn" (buffer-string)))
              (should (string-match-p "bad-fn" (buffer-string)))
              (should (string-match-p "0%" (buffer-string))))))
      (kill-buffer buf)
      (delete-file file))))

(ert-deftest testcover-audit-report-test--batch-report-with-low-funcs ()
  "Test batch-report includes function-level breakdown for low coverage."
  (let ((testcover-audit--loaded-files
         (list (cons (file-truename (expand-file-name "a.el" temporary-file-directory))
                     (list (cons 'high-fn [edebug-ok-coverage edebug-ok-coverage])
                           (cons 'low-fn [edebug-unknown edebug-unknown]))))))
    (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
      (testcover-audit-report--batch-report))
    (with-current-buffer "*Testcover Batch Report*"
      (should (string-match-p "Function-level breakdown" (buffer-string)))
      (should (string-match-p "low-fn" (buffer-string))))))

(ert-deftest testcover-audit-report-test--batch-report-no-data-msg ()
  "Test batch-report shows message when no data is collected."
  (let ((testcover-audit--loaded-files nil)
        (msg-captured nil))
    (cl-letf (((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) msg-captured))))
      (testcover-audit-report--batch-report))
    (should (seq-some (lambda (m) (string-match-p "No coverage data collected" m)) msg-captured))))

(ert-deftest testcover-audit-report-test--stats-for-file-live ()
  "Stats-for-file prefers live buffer data over the scan snapshot."
  (let* ((file (make-temp-file "tca-live-stats" nil ".el"))
         (symbol (make-symbol "tca-live-stats-fn"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (setq-local edebug-form-data
                      (list (edebug--make-form-data-entry
                             symbol
                             (copy-marker (point-min))
                             (copy-marker (point-max)))))
          (put symbol 'edebug-behavior 'testcover)
          (put symbol 'edebug-coverage
               [edebug-ok-coverage edebug-ok-coverage edebug-ok-coverage])
          ;; Stale snapshot must not shadow live data.
          (let ((testcover-audit--loaded-files
                 (list (cons (file-truename file)
                             (list (cons symbol [edebug-unknown edebug-unknown]))))))
            (let ((stats (testcover-audit-report--stats-for-file file)))
              (should (= (plist-get stats :total) 3))
              (should (= (plist-get stats :percent) 100)))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-all-stats-live ()
  "Show-all-stats works from live buffer data without a scan snapshot."
  (let* ((file (make-temp-file "tca-live-all" nil ".el"))
         (symbol (make-symbol "tca-live-all-fn"))
         (buf (find-file-noselect file))
         (display-buffer-called nil))
    (unwind-protect
        (with-current-buffer buf
          (setq-local edebug-form-data
                      (list (edebug--make-form-data-entry
                             symbol
                             (copy-marker (point-min))
                             (copy-marker (point-max)))))
          (put symbol 'edebug-behavior 'testcover)
          (put symbol 'edebug-coverage
               [edebug-unknown testcover-1value
                edebug-ok-coverage edebug-ok-coverage])
          (let ((testcover-audit--loaded-files nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-all-stats)))
          (should display-buffer-called)
          (with-current-buffer "*Testcover Audit Report*"
            (should (string-match-p "Function-level breakdown" (buffer-string)))
            (should (string-match-p "75" (buffer-string)))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-function-stats-live ()
  "Show-function-stats lists live functions without a scan snapshot."
  (let* ((file (make-temp-file "tca-live-fn" nil ".el"))
         (symbol (make-symbol "tca-live-fn"))
         (buf (find-file-noselect file))
         (display-buffer-called nil))
    (unwind-protect
        (with-current-buffer buf
          (setq-local edebug-form-data
                      (list (edebug--make-form-data-entry
                             symbol
                             (copy-marker (point-min))
                             (copy-marker (point-max)))))
          (put symbol 'edebug-behavior 'testcover)
          (put symbol 'edebug-coverage
               [edebug-unknown edebug-unknown edebug-unknown])
          (let ((testcover-audit--loaded-files nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-function-stats)))
          (should display-buffer-called)
          (with-current-buffer "*Testcover Function Report*"
            (should (string-match-p "tca-live-fn" (buffer-string)))
            (should (string-match-p "0%" (buffer-string)))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-all-stats-no-line-level ()
  "Show-all-stats skips line-level breakdown even with position data."
  (let* ((file (make-temp-file "tca-all-no-line" nil ".el"))
         (symbol (make-symbol "tca-all-no-line-fn"))
         (buf (find-file-noselect file))
         (display-buffer-called nil))
    (unwind-protect
        (with-current-buffer buf
          (insert "(defun tca-all-no-line-fn ()\n"
                  "  (message \"hi\")\n"
                  "  nil)\n")
          (setq-local edebug-form-data
                      (list (edebug--make-form-data-entry
                             symbol
                             (copy-marker (point-min))
                             (copy-marker (point-max)))))
          (put symbol 'edebug
               (list (copy-marker (point-min)) nil (vector 0 20 40)))
          (put symbol 'edebug-behavior 'testcover)
          (put symbol 'edebug-coverage
               [edebug-unknown edebug-ok-coverage edebug-ok-coverage])
          (let ((testcover-audit--loaded-files nil))
            (cl-letf (((symbol-function 'display-buffer)
                       (lambda (&rest _) (setq display-buffer-called t))))
              (testcover-audit-report--show-all-stats)))
          (should display-buffer-called)
          (with-current-buffer "*Testcover Audit Report*"
            (should (string-match-p "Function-level breakdown" (buffer-string)))
            (should-not (string-match-p "Line-level breakdown" (buffer-string)))))
      (cl-remprop symbol 'edebug)
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (delete-file file))))

(provide 'testcover-audit-report-test)
;;; testcover-audit-report-test.el ends here
