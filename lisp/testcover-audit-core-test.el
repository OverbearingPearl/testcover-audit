;;; testcover-audit-core-test.el --- Tests for testcover-audit-core -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for the pure statistics engine.

;;; Code:

(require 'ert)
(require 'testcover-audit-core)
(require 'testcover-audit-util-test)

(ert-deftest testcover-audit-core-test--collect-stats ()
  "Test parsing of an edebug-coverage vector."
  (let* ((current (vector 'edebug-unknown
                          (cons testcover-audit-util-test--1value 1)
                          'edebug-ok-coverage 'edebug-ok-coverage))
         (baseline (testcover-audit-util-test--unknown-baseline current))
         (stats (testcover-audit-core--collect-stats current baseline)))
    (should (= (plist-get stats :total) 4))
    (should (= (plist-get stats :covered) 2))
    (should (= (plist-get stats :onevalue) 1))
    (should (= (plist-get stats :uncovered) 1))
    (should (= (plist-get stats :percent) 75))))

(ert-deftest testcover-audit-core-test--static-before-slots-ignored ()
  "Baseline `edebug-ok-coverage' slots are before markers, not coverage."
  (let ((baseline [edebug-ok-coverage edebug-unknown
                   edebug-ok-coverage edebug-unknown])
        (current [edebug-ok-coverage edebug-unknown
                  edebug-ok-coverage edebug-unknown]))
    (let ((stats (testcover-audit-core--collect-stats current baseline)))
      (should (= (plist-get stats :total) 2))
      (should (= (plist-get stats :uncovered) 2))
      (should (= (plist-get stats :covered) 0))
      (should (= (plist-get stats :percent) 0)))))

(ert-deftest testcover-audit-core-test--missing-baseline-fails ()
  "Collect-stats fails loud without a baseline."
  (should-error (testcover-audit-core--collect-stats [edebug-unknown] nil)
                :type 'user-error))

(ert-deftest testcover-audit-core-test--collect-stats-ignores-noreturn ()
  "Test that non-returning forms are excluded from coverage totals."
  (let* ((baseline [edebug-unknown (noreturn . 1) edebug-unknown])
         (stats
          (testcover-audit-core--collect-stats
           [edebug-ok-coverage (noreturn . 1) edebug-unknown]
           baseline)))
    (should (= (plist-get stats :total) 2))
    (should (= (plist-get stats :covered) 1))
    (should (= (plist-get stats :uncovered) 1))
    (should (= (plist-get stats :ignored) 1))
    (should (= (plist-get stats :percent) 50))))

(ert-deftest testcover-audit-core-test--collect-stats-observed-values ()
  "Test that observed testcover result values count as onevalue."
  (let* ((baseline [edebug-unknown edebug-unknown
                    edebug-unknown edebug-unknown
                    edebug-unknown (noreturn . 17)])
         (stats
          (testcover-audit-core--collect-stats
           [edebug-unknown
            edebug-ok-coverage
            "single-result"
            fixture-symbol
            nil
            (noreturn . 17)]
           baseline)))
    (should (= (plist-get stats :total) 5))
    (should (= (plist-get stats :covered) 1))
    (should (= (plist-get stats :onevalue) 3))
    (should (= (plist-get stats :uncovered) 1))
    (should (= (plist-get stats :ignored) 1))
    (should (= (plist-get stats :percent) 80))))

(ert-deftest testcover-audit-core-test--aggregate ()
  "Test aggregation of multiple stats plists."
  (let* ((a (list :total 2 :covered 1 :onevalue 0 :uncovered 1))
         (b (list :total 3 :covered 2 :onevalue 1 :uncovered 0))
         (agg (testcover-audit-core--aggregate (list a b))))
    (should (= (plist-get agg :total) 5))
    (should (= (plist-get agg :covered) 3))
    (should (= (plist-get agg :onevalue) 1))
    (should (= (plist-get agg :uncovered) 1))
    (should (= (plist-get agg :ignored) 0))
    (should (= (plist-get agg :percent) 80))))

(ert-deftest testcover-audit-core-test--percent ()
  "Test percentage calculation."
  (should (= (testcover-audit-core--percent 40 80) 50))
  (should (= (testcover-audit-core--percent 5 8) 63))
  (should (= (testcover-audit-core--percent 0 0) 100)))

(ert-deftest testcover-audit-core-test--all-files-stats ()
  "Test aggregate stats when collected files are present."
  (let ((testcover-audit-core--loaded-files
         (list (cons "a.el"
                     (list (cons 'a-function
                                 (vector 'edebug-unknown
                                         testcover-audit-util-test--1value
                                         'edebug-ok-coverage
                                         'edebug-ok-coverage))))
               (cons "b.el"
                     (list (cons 'b-function
                                 (vector 'edebug-unknown 'edebug-unknown
                                         testcover-audit-util-test--1value
                                         testcover-audit-util-test--1value)))))))
    (testcover-audit-util-test--install-baselines
     testcover-audit-core--loaded-files)
    (let ((stats (testcover-audit-core--all-files-stats)))
      (should (= (plist-get stats :total) 8))
      (should (= (plist-get stats :percent) 63))))
  (let ((testcover-audit-core--loaded-files nil))
    (should (null (testcover-audit-core--all-files-stats)))))

(provide 'testcover-audit-core-test)
;;; testcover-audit-core-test.el ends here
