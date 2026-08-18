# testcover-audit

**Testcover Audit** adds quantitative coverage statistics to Emacs' built-in `testcover.el`.  
It shows the coverage percentage, the counts of covered, uncovered, and 1value forms, and can generate per-file and per-function breakdowns. If you've ever wondered “how much of my code is actually tested?”, testcover-audit gives you the answer in numbers.

## Features

- **Coverage percentage in the current buffer** – `testcover-audit-mode` displays the current file's coverage in the mode line.
- **Detailed file report** – `testcover-audit-show-all-stats` opens a dedicated `*Testcover Audit Report*` buffer with a colored table.
- **Per-function report** – `testcover-audit-show-function-stats` groups forms by function, helping you locate the exact uncovered logic.
- **Directory scanning** – `testcover-audit-scan-directory` recursively instruments all `.el` files, respects dependency order, and logs errors.
- **Batch report** – `testcover-audit-batch-report` aggregates statistics for all instrumented files and shows a summary table.
- **Org and JSON export** – `testcover-audit-export-org` and `testcover-audit-export-json` produce shareable, machine-readable reports.
- **CI-ready threshold check** – `testcover-audit-ci-check` exits with a non-zero status when coverage is below `testcover-audit-ci-threshold`.
- **project.el integration** – `testcover-audit-project-report` automatically determines the project root and runs a one-command full analysis.
- **ERT integration** – `testcover-audit-ert-mode` automatically generates reports after ERT test runs.

## Installation

### From MELPA

```elisp
M-x package-install RET testcover-audit RET
```

### Manual installation

Clone the repository and add both the project root and `lisp/` subdirectory to `load-path`:

```elisp
(add-to-list 'load-path "/path/to/testcover-audit")
(add-to-list 'load-path "/path/to/testcover-audit/lisp")
(require 'testcover-audit)
```

## Usage

### 1. Show statistics for the current buffer

```elisp
M-x testcover-audit-show-stats
```

*If the buffer is not yet instrumented, an error message reminds you to run `testcover-start` first.*

### 2. Show the detailed file report

```elisp
M-x testcover-audit-show-all-stats
```

The report is displayed in a dedicated buffer and is color-coded according to your thresholds.

### 3. Scan a whole directory

```elisp
M-x testcover-audit-scan-directory RET /path/to/project
```

All `.el` files under that directory are instrumented in dependency order, and a progress message is shown.

### 4. Generate a batch report

```elisp
M-x testcover-audit-batch-report
```

The buffer shows a table with **Forms**, **Covered**, **1value**, **Uncovered**, and **Coverage** columns, plus a total row.

### 5. Export reports

```elisp
M-x testcover-audit-export-org RET /tmp/coverage.org
M-x testcover-audit-export-json RET /tmp/coverage.json
```

### 6. Use in CI

```elisp
emacs -Q --batch -L . -L lisp \
      -l testcover-audit \
      -l testcover-audit-export \
      -f testcover-audit-scan-directory /path/to/project \
      -f testcover-audit-ci-check
```

If the overall coverage is less than `testcover-audit-ci-threshold`, the process exits with a non-zero status.

### 7. ERT integration

```elisp
M-x testcover-audit-ert-mode
```

After each ERT run, a coverage report is automatically generated if `testcover-audit-auto-show-report` is non-nil.

## Customization

`M-x customize-group RET testcover-audit RET`

| Option | Default | Description |
|--------|---------|-------------|
| `testcover-audit-green-threshold` | 80 | Coverage % at/above which the report is green. |
| `testcover-audit-yellow-threshold` | 50 | Coverage % below which the report is red. |
| `testcover-audit-report-format` | `table` | Report format: `table` or `list`. |
| `testcover-audit-exclude-files` | `("^\\." "\\.elc$")` | Regexps for excluding files from directory scans. |
| `testcover-audit-auto-show-report` | `nil` | Automatically display the report after ERT runs. |
| `testcover-audit-ci-threshold` | 80 | Minimum coverage % required by `testcover-audit-ci-check`. |

## Notes

- This package only works on files that have been instrumented with `testcover-start`.
- The report colors are based on the current buffer's `default` face, so they integrate well with your theme.
- The dependency ordering performed by `testcover-audit-scan-directory` uses a simple topological sort on `require` forms, which is sufficient for most Emacs Lisp projects.

## License

GPL-3.0-or-later, see `LICENSE` file.
