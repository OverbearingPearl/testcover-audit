#!/bin/sh
# Export project metadata derived from ci/config.el and the repository.
# Usage: ci/config-export.sh versions|lint|package|version
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$here/..")
emacs_bin=${EMACS:-emacs}
key=${1:?usage: config-export.sh versions|lint|package|version}

cd "$root"

# Stop once the value is printed.  The key is a positional argument and
# would otherwise be visited as a file; `vendor' is a directory, so Emacs
# would open it with dired and probe `ls --dired' along the way.
exec "$emacs_bin" -Q --batch \
  -l "$here/config.el" \
  -l "$here/lib/util.el" \
  -l "$here/lib/project.el" \
  --eval '(progn (p/config-export command-line-args-left) (kill-emacs 0))' \
  -- "$key"
