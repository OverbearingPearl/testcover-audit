# pearl-testcover

**Pearl Testcover** adds quantitative coverage statistics to Emacs' built-in `testcover.el`.  
It shows the coverage percentage, the counts of covered, uncovered, and 1value forms, and can generate per-file and per-function breakdowns. If you've ever wondered “how much of my code is actually tested?”, pearl-testcover gives you the answer in numbers.

## Features

- **Coverage percentage in the current buffer** – `pearl-testcover-mode` displays the current file's coverage in the mode line.
- **Detailed file report** – `pearl-testcover-show-all-stats` opens a dedicated `*Pearl Testcover Report*` buffer with a colored table.
- **Per-function report** – `pearl-testcover-show-function-stats` groups forms by function, helping you locate the exact uncovered logic.
- **Directory scanning** – `pearl-testcover-scan-directory` recursively instruments all `.el` files, respects dependency order, and logs errors.
- **Batch report** – `pearl-testcover-batch-report` aggregates statistics for all instrumented files and shows a summary table.
- **Org and JSON export** – `pearl-testcover-export-org` and `pearl-testcover-export-json` produce shareable, machine-readable reports.
- **CI-ready threshold check** – `pearl-testcover-ci-check` exits with a non-zero status when coverage is below `pearl-testcover-ci-threshold`.
- **project.el integration** – `pearl-testcover-project-report` automatically determines the project root and runs a one-command full analysis.
- **ERT integration** – `pearl-testcover-ert-mode` automatically generates reports after ERT test runs.

## Installation

### From MELPA

```elisp
M-x package-install RET pearl-testcover RET
```

### Manual installation

Clone the repository and add both the project root and `lisp/` subdirectory to `load-path`:

```elisp
(add-to-list 'load-path "/path/to/pearl-testcover")
(add-to-list 'load-path "/path/to/pearl-testcover/lisp")
(require 'pearl-testcover)
```

## Usage

### 1. Show statistics for the current buffer

```elisp
M-x pearl-testcover-show-stats
```

*If the buffer is not yet instrumented, an error message reminds you to run `testcover-start` first.*

### 2. Show the detailed file report

```elisp
M-x pearl-testcover-show-all-stats
```

The report is displayed in a dedicated buffer and is color-coded according to your thresholds.

### 3. Scan a whole directory

```elisp
M-x pearl-testcover-scan-directory RET /path/to/project
```

All `.el` files under that directory are instrumented in dependency order, and a progress message is shown.

### 4. Generate a batch report

```elisp
M-x pearl-testcover-batch-report
```

The buffer shows a table with **Forms**, **Covered**, **1value**, **Uncovered**, and **Coverage** columns, plus a total row.

### 5. Export reports

```elisp
M-x pearl-testcover-export-org RET /tmp/coverage.org
M-x pearl-testcover-export-json RET /tmp/coverage.json
```

### 6. Use in CI

```elisp
emacs -Q --batch -L . -L lisp \
      -l pearl-testcover \
      -l pearl-testcover-export \
      -f pearl-testcover-scan-directory /path/to/project \
      -f pearl-testcover-ci-check
```

If the overall coverage is less than `pearl-testcover-ci-threshold`, the process exits with a non-zero status.

### 7. ERT integration

```elisp
M-x pearl-testcover-ert-mode
```

After each ERT run, a coverage report is automatically generated if `pearl-testcover-auto-show-report` is non-nil.

## Customization

`M-x customize-group RET pearl-testcover RET`

| Option | Default | Description |
|--------|---------|-------------|
| `pearl-testcover-green-threshold` | 80 | Coverage % at/above which the report is green. |
| `pearl-testcover-yellow-threshold` | 50 | Coverage % below which the report is red. |
| `pearl-testcover-report-format` | `table` | Report format: `table` or `list`. |
| `pearl-testcover-exclude-files` | `("^\\." "\\.elc$")` | Regexps for excluding files from directory scans. |
| `pearl-testcover-auto-show-report` | `nil` | Automatically display the report after ERT runs. |
| `pearl-testcover-ci-threshold` | 80 | Minimum coverage % required by `pearl-testcover-ci-check`. |

## Notes

- This package only works on files that have been instrumented with `testcover-start`.
- The report colors are based on the current buffer's `default` face, so they integrate well with your theme.
- The dependency ordering performed by `pearl-testcover-scan-directory` uses a simple topological sort on `require` forms, which is sufficient for most Emacs Lisp projects.

## License

GPL-3.0-or-later, see `LICENSE` file.
