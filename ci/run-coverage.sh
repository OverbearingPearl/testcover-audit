#!/bin/sh
# Report what the test suite reaches. The measuring lives in ci/coverage.el;
# where it looks is the :coverage table of ci/config.el. Nothing here fails on
# a number: instrumentation changes what the code does, so the test job owns
# correctness and this one owns having a report to read. A run that collects
# nothing, or a file that cannot be instrumented, is the exception: that is
# not a report at all.
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
  -l "$here/coverage.el" \
  --eval '(p/coverage-main-or-die)'
