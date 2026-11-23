#!/bin/sh
# Run the check suite. See ci/README.md for the rules themselves.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$here/..")
emacs_bin=${EMACS:-emacs}

command -v "$emacs_bin" >/dev/null 2>&1 || {
  echo "emacs not found; install Emacs or set EMACS=/path/to/emacs" >&2
  exit 1
}

cd "$root"

exec "$emacs_bin" -Q --batch \
  -l "$here/config.el" \
  -l "$here/lib/util.el" \
  -l "$here/lib/project.el" \
  -l "$here/deps.el" \
  --eval "(p/ensure-package 'package-lint 'package-lint)" \
  --eval '(p/ensure-test-packages)' \
  -l "$here/lib/report.el" \
  -l "$here/lib/registry.el" \
  --eval "(p/load-checks (expand-file-name \"checks\" \"$here\"))" \
  --eval '(p/main command-line-args-left)' \
  -- "$@"
