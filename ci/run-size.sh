#!/bin/sh
# Print what each module costs and where the same lines sit twice.
#
# The measuring lives in ci/size.el; where it looks and how long a run has to
# be live in the :size table of ci/config.el. Nothing here fails on a number:
# size is a report, not a budget, so the exit status is zero and the table on
# standard output is the whole answer.
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
  -l "$here/lib/project.el" \
  -l "$here/size.el" \
  --eval '(kill-emacs (p/size-main))'
