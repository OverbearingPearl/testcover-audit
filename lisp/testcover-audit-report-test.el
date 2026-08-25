;;; testcover-audit-report-test.el --- Tests for testcover-audit-report -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for report rendering.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edebug)
(require 'testcover-audit-report)
(require 'testcover-audit-util-test)

(defun testcover-audit-report-test--kill-report-buffer (name)
  "Kill report buffer NAME if it is live."
  (when (buffer-live-p (get-buffer name))
    (kill-buffer name)))

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
  (let ((testcover-audit-core--loaded-files
         (list (cons (file-truename (expand-file-name "a.el"))
                     (list (cons 'a-function [edebug-unknown testcover-1value
                                              edebug-ok-coverage edebug-ok-coverage])))
               (cons (file-truename (expand-file-name "b.el"))
                     (list (cons 'b-function [edebug-unknown edebug-unknown
                                              testcover-1value testcover-1value]))))))
    (testcover-audit-util-test--install-baselines
     testcover-audit-core--loaded-files)
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
            (testcover-audit-report--batch-report))
          (with-current-buffer "*Testcover Batch Report*"
            (should (string-match-p "63" (buffer-string)))))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Batch Report*"))))

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
          (setq testcover-audit-core--loaded-files nil)
          (should (null (testcover-audit-report--stats-for-file "no-such-file.el"))))
      (kill-buffer buf))))

(ert-deftest testcover-audit-report-test--show-stats-with-coverage ()
  "Message shows coverage from the collected function snapshot."
  (let* ((file (make-temp-file "tca-msg-cov" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit-core--loaded-files
                 `((,(file-truename file) . ((fixture-function . [edebug-unknown
                                                                  testcover-1value
                                                                  edebug-ok-coverage
                                                                  edebug-ok-coverage])))))
                (messages nil))
            (testcover-audit-util-test--install-baselines
             testcover-audit-core--loaded-files)
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
          (let ((testcover-audit-core--loaded-files
                 `((,(file-truename file) . ((fixture-fn . [edebug-unknown
                                                            testcover-1value
                                                            edebug-ok-coverage
                                                            edebug-ok-coverage])))))
                (_display-buffer-called nil))
            (testcover-audit-util-test--install-baselines
             testcover-audit-core--loaded-files)
            (testcover-audit-report--show-all-stats)
            (should (eq (current-buffer)
                        (get-buffer "*Testcover Audit Report*")))
            (with-current-buffer "*Testcover Audit Report*"
              (should (string-match-p "Testcover Audit Report" (buffer-string)))
              (should (string-match-p "Function-level breakdown" (buffer-string)))
              (should (string-match-p "75" (buffer-string))))))
      (kill-buffer buf)
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Audit Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-function-stats-line-level ()
  "Show-function-stats shows line breakdown with live position data."
  (let* ((file (make-temp-file "tca-line-report" nil ".el"))
         (symbol (make-symbol "tca-line-report-fn"))
         (buf (find-file-noselect file))
         (_display-buffer-called nil))
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
          (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq))
          (testcover-audit-util-test--install-symbol-baseline
           symbol (get symbol 'edebug-coverage))
          (let ((testcover-audit-core--loaded-files nil))
            (testcover-audit-report--show-function-stats))
          (should (eq (current-buffer)
                      (get-buffer "*Testcover Function Report*")))
          (with-current-buffer "*Testcover Function Report*"
            (should (string-match-p "Testcover Function Report" (buffer-string)))
            (should (string-match-p "tca-line-report-fn" (buffer-string)))
            (should (string-match-p "Line" (buffer-string)))
            (should (string-match-p "Coverage" (buffer-string)))
            (should (string-match-p "Uncovered" (buffer-string)))))
      (cl-remprop symbol 'edebug)
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (set-buffer-modified-p nil))
        (kill-buffer buf))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Function Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-function-stats-mixed ()
  "Test show-function-stats lists functions with varying coverage."
  (let* ((file (make-temp-file "tca-func-stats" nil ".el"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit-core--loaded-files
                 (list (cons (file-truename file)
                             (list (cons 'good-fn [edebug-ok-coverage edebug-ok-coverage])
                                   (cons 'bad-fn [edebug-unknown edebug-unknown])))))
                (_display-buffer-called nil))
            (testcover-audit-util-test--install-baselines
             testcover-audit-core--loaded-files)
            (testcover-audit-report--show-function-stats)
            (should (eq (current-buffer)
                        (get-buffer "*Testcover Function Report*")))
            (with-current-buffer "*Testcover Function Report*"
              (should (string-match-p "good-fn" (buffer-string)))
              (should (string-match-p "bad-fn" (buffer-string)))
              (should (string-match-p "0%" (buffer-string))))))
      (kill-buffer buf)
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Function Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--batch-report-with-low-funcs ()
  "Test batch-report includes function-level breakdown for low coverage."
  (let ((testcover-audit-core--loaded-files
         (list (cons (file-truename (expand-file-name "a.el" temporary-file-directory))
                     (list (cons 'high-fn [edebug-ok-coverage edebug-ok-coverage])
                           (cons 'low-fn [edebug-unknown edebug-unknown]))))))
    (testcover-audit-util-test--install-baselines
     testcover-audit-core--loaded-files)
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
            (testcover-audit-report--batch-report))
          (with-current-buffer "*Testcover Batch Report*"
            (should (string-match-p "Function-level breakdown" (buffer-string)))
            (should (string-match-p "low-fn" (buffer-string)))))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Batch Report*"))))

(ert-deftest testcover-audit-report-test--batch-report-no-data-msg ()
  "Test batch-report shows message when no data is collected."
  (let ((testcover-audit-core--loaded-files nil)
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
          (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq))
          (testcover-audit-util-test--install-symbol-baseline
           symbol (get symbol 'edebug-coverage))
          ;; Stale snapshot must not shadow live data.
          (let ((testcover-audit-core--loaded-files
                 (list (cons (file-truename file)
                             (list (cons symbol [edebug-unknown edebug-unknown]))))))
            (let ((stats (testcover-audit-report--stats-for-file file)))
              (should (= (plist-get stats :total) 3))
              (should (= (plist-get stats :percent) 100)))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Audit Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-all-stats-live ()
  "Show-all-stats works from live buffer data without a scan snapshot."
  (let* ((file (make-temp-file "tca-live-all" nil ".el"))
         (symbol (make-symbol "tca-live-all-fn"))
         (buf (find-file-noselect file))
         (_display-buffer-called nil))
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
          (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq))
          (testcover-audit-util-test--install-symbol-baseline
           symbol (get symbol 'edebug-coverage))
          (let ((testcover-audit-core--loaded-files nil))
            (testcover-audit-report--show-all-stats))
          (should (eq (current-buffer)
                      (get-buffer "*Testcover Audit Report*")))
          (with-current-buffer "*Testcover Audit Report*"
            (should (string-match-p "Function-level breakdown" (buffer-string)))
            (should (string-match-p "75" (buffer-string)))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Function Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-function-stats-live ()
  "Show-function-stats lists live functions without a scan snapshot."
  (let* ((file (make-temp-file "tca-live-fn" nil ".el"))
         (symbol (make-symbol "tca-live-fn"))
         (buf (find-file-noselect file))
         (_display-buffer-called nil))
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
          (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq))
          (testcover-audit-util-test--install-symbol-baseline
           symbol (get symbol 'edebug-coverage))
          (let ((testcover-audit-core--loaded-files nil))
            (testcover-audit-report--show-function-stats))
          (should (eq (current-buffer)
                      (get-buffer "*Testcover Function Report*")))
          (with-current-buffer "*Testcover Function Report*"
            (should (string-match-p "tca-live-fn" (buffer-string)))
            (should (string-match-p "0%" (buffer-string)))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Function Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--show-all-stats-no-line-level ()
  "Show-all-stats skips line-level breakdown even with position data."
  (let* ((file (make-temp-file "tca-all-no-line" nil ".el"))
         (symbol (make-symbol "tca-all-no-line-fn"))
         (buf (find-file-noselect file))
         (_display-buffer-called nil))
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
          (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq))
          (testcover-audit-util-test--install-symbol-baseline
           symbol (get symbol 'edebug-coverage))
          (let ((testcover-audit-core--loaded-files nil))
            (testcover-audit-report--show-all-stats))
          (should (eq (current-buffer)
                      (get-buffer "*Testcover Audit Report*")))
          (with-current-buffer "*Testcover Audit Report*"
            (should (string-match-p "Function-level breakdown" (buffer-string)))
            (should-not (string-match-p "Line-level breakdown" (buffer-string)))))
      (cl-remprop symbol 'edebug)
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (set-buffer-modified-p nil))
        (kill-buffer buf))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Audit Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--format-list ()
  "Test list format rendering when `testcover-audit-report-format' is list."
  (with-temp-buffer
    (let ((testcover-audit-report-format 'list))
      (testcover-audit-report--insert-table
       '(("Function" text) ("Total" number) ("Coverage" percent))
       '(("foo" 4 75))))
    (should (string-match-p "Function: foo" (buffer-string)))
    (should (string-match-p "Total: 4" (buffer-string)))
    (should (string-match-p "Coverage: 75%" (buffer-string)))))

(ert-deftest testcover-audit-report-test--batch-report-low-coverage-threshold ()
  "Test batch-report honors `testcover-audit-low-coverage-threshold'."
  (let* ((file (file-truename (expand-file-name "a.el" temporary-file-directory)))
         (testcover-audit-core--loaded-files
          (list (cons file
                      (list (cons 'ok-fn [edebug-ok-coverage edebug-ok-coverage
                                          edebug-ok-coverage])
                            (cons 'partial-fn [edebug-unknown edebug-ok-coverage
                                               edebug-ok-coverage])))))
         (testcover-audit-low-coverage-threshold 90))
    (testcover-audit-util-test--install-baselines
     testcover-audit-core--loaded-files)
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
            (testcover-audit-report--batch-report))
          (with-current-buffer "*Testcover Batch Report*"
            (should (string-match-p "partial-fn" (buffer-string)))
            (should-not (string-match-p "ok-fn" (buffer-string)))
            (should (string-match-p "Uncovered" (buffer-string)))))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Batch Report*"))))

(ert-deftest testcover-audit-report-test--navigation-map ()
  "Report buffers use the navigation keymap with j/k/n/p bindings."
  (let ((testcover-audit-core--loaded-files
         (list (cons (file-truename
                      (expand-file-name "a.el" temporary-file-directory))
                     (list (cons 'fn [edebug-unknown edebug-unknown])))))
        (_display-buffer-called nil))
    (testcover-audit-util-test--install-baselines
     testcover-audit-core--loaded-files)
    (unwind-protect
        (progn
          (testcover-audit-report--batch-report)
          (should (eq (current-buffer)
                      (get-buffer "*Testcover Batch Report*")))
          (with-current-buffer "*Testcover Batch Report*"
            (should (eq (current-local-map)
                        testcover-audit-report--navigation-map))
            (should (eq (lookup-key (current-local-map) (kbd "j")) #'next-line))
            (should (eq (lookup-key (current-local-map) (kbd "k")) #'previous-line))
            (should (eq (lookup-key (current-local-map) (kbd "n")) #'next-line))
            (should (eq (lookup-key (current-local-map) (kbd "p")) #'previous-line)))))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Batch Report*")))

(ert-deftest testcover-audit-report-test--function-report-navigation-map ()
  "Function report buffer uses the navigation keymap."
  (let* ((file (make-temp-file "tca-fn-nav-map" nil ".el"))
         (buf (find-file-noselect file))
         (_display-buffer-called nil))
    (unwind-protect
        (with-current-buffer buf
          (let ((testcover-audit-core--loaded-files
                 (list (cons (file-truename file)
                             (list (cons 'fn [edebug-unknown edebug-unknown]))))))
            (testcover-audit-util-test--install-baselines
             testcover-audit-core--loaded-files)
            (testcover-audit-report--show-function-stats))
          (should (eq (current-buffer)
                      (get-buffer "*Testcover Function Report*")))
          (with-current-buffer "*Testcover Function Report*"
            (should (eq (current-local-map)
                        testcover-audit-report--navigation-map))))
      (kill-buffer buf)
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Function Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--row-navigation-properties ()
  "Insert-table adds navigation properties when row-props-fn is provided."
  (with-temp-buffer
    (testcover-audit-report--insert-table
     '(("File" text) ("Total" number))
     '(("a.el" 1))
     (lambda (_row _idx)
       (list :keymap testcover-audit-report--file-stats-keymap
             :file "/tmp/a.el")))
    (goto-char (point-min))
    (forward-line 2)                  ; skip header and separator
    (should (eq (get-text-property (point) 'keymap)
                testcover-audit-report--file-stats-keymap))
    (should (string= (get-text-property (point) 'testcover-audit-report-file)
                     "/tmp/a.el"))))

(ert-deftest testcover-audit-report-test--row-navigation-mouse-bindings ()
  "Report row keymaps activate their targets with the mouse."
  (should (eq (lookup-key testcover-audit-report--file-stats-keymap
                          [mouse-2])
              #'testcover-audit-report--goto-file-stats-command))
  (should (eq (lookup-key testcover-audit-report--function-stats-keymap
                          [mouse-2])
              #'testcover-audit-report--goto-function-stats-command)))

(ert-deftest testcover-audit-report-test--batch-report-row-navigation ()
  "Batch report binds file rows and function rows for navigation."
  (let ((testcover-audit-core--loaded-files
         (list (cons (file-truename (expand-file-name "a.el" temporary-file-directory))
                     (list (cons 'high-fn [edebug-ok-coverage edebug-ok-coverage])
                           (cons 'low-fn [edebug-unknown edebug-unknown]))))))
    (testcover-audit-util-test--install-baselines
     testcover-audit-core--loaded-files)
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
            (testcover-audit-report--batch-report))
          (with-current-buffer "*Testcover Batch Report*"
            ;; File row: locate the first row carrying the file navigation property.
            (goto-char (point-min))
            (let ((match (text-property-search-forward 'testcover-audit-report-file)))
              (should match)
              (goto-char (prop-match-beginning match))
              (should (eq (get-text-property (point) 'keymap)
                          testcover-audit-report--file-stats-keymap))
              (should (string= (get-text-property (point) 'testcover-audit-report-file)
                               (file-truename
                                (expand-file-name "a.el" temporary-file-directory)))))
            ;; Function row: locate the first low-function row carrying the
            ;; function navigation property.
            (goto-char (point-min))
            (let ((match (text-property-search-forward 'testcover-audit-report-function)))
              (should match)
              (goto-char (prop-match-beginning match))
              (should (eq (get-text-property (point) 'keymap)
                          testcover-audit-report--function-stats-keymap))
              (should (string= (get-text-property (point) 'testcover-audit-report-function)
                               "low-fn"))))))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Batch Report*")))

(ert-deftest testcover-audit-report-test--goto-file-stats ()
  "Goto-file-stats calls show-all-stats with the associated file."
  (let (called)
    (cl-letf (((symbol-function 'testcover-audit-report--show-all-stats)
               (lambda (file) (setq called file))))
      (with-temp-buffer
        (insert "x")
        (put-text-property (point-min) (point-max)
                           'testcover-audit-report-file "/tmp/a.el")
        (goto-char (point-min))
        (testcover-audit-report--goto-file-stats)
        (should (string= called "/tmp/a.el"))))))

(ert-deftest testcover-audit-report-test--goto-function-stats ()
  "Goto-function-stats calls show-function-stats with file and function."
  (let (called-file called-function)
    (cl-letf (((symbol-function 'testcover-audit-report--show-function-stats)
               (lambda (file function)
                 (setq called-file file)
                 (setq called-function function))))
      (with-temp-buffer
        (insert "x")
        (put-text-property (point-min) (point-max)
                           'testcover-audit-report-file "/tmp/a.el")
        (put-text-property (point-min) (point-max)
                           'testcover-audit-report-function "low-fn")
        (goto-char (point-min))
        (testcover-audit-report--goto-function-stats)
        (should (string= called-file "/tmp/a.el"))
        (should (string= called-function "low-fn"))))))

(ert-deftest testcover-audit-report-test--show-function-stats-with-function ()
  "Show-function-stats moves point to the requested function."
  (let* ((file (make-temp-file "tca-nav-fn" nil ".el"))
         (symbol (make-symbol "tca-nav-target"))
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
               [edebug-unknown edebug-unknown edebug-unknown])
          (setq testcover-audit-core--initial-vectors (make-hash-table :test 'eq))
          (testcover-audit-util-test--install-symbol-baseline
           symbol (get symbol 'edebug-coverage))
          (cl-letf (((symbol-function 'display-buffer) (lambda (&rest _) nil)))
            (testcover-audit-report--show-function-stats file "tca-nav-target"))
          (with-current-buffer "*Testcover Function Report*"
            (should (looking-at "tca-nav-target"))))
      (cl-remprop symbol 'edebug-behavior)
      (cl-remprop symbol 'edebug-coverage)
      (when (buffer-live-p buf) (kill-buffer buf))
      (testcover-audit-report-test--kill-report-buffer
       "*Testcover Function Report*")
      (delete-file file))))

(ert-deftest testcover-audit-report-test--project-report ()
  "Project-report scans root and generates batch report."
  (let* ((dir (make-temp-file "tca-proj" t))
         (git-dir (expand-file-name ".git" dir)))
    (unwind-protect
        (progn
          (make-directory git-dir)
          (let ((default-directory dir)
                (scan-called nil)
                (report-called nil))
            (cl-letf (((symbol-function 'testcover-audit-scan--scan-directory)
                       (lambda (_) (setq scan-called t)))
                      ((symbol-function 'testcover-audit-report--batch-report)
                       (lambda () (setq report-called t))))
              (testcover-audit-report--project-report))
            (should scan-called)
            (should report-called)))
      (delete-directory dir t))))

(provide 'testcover-audit-report-test)
;;; testcover-audit-report-test.el ends here
