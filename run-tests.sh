#!/bin/sh
# Run the ERT test suite. Test files are discovered, never listed:
# every .el file under the test directory.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$here/..")
emacs_bin=${EMACS:-emacs}
submodule=$("$here/config-export.sh" submodule)
testdir=$("$here/config-export.sh" test-dir)
vendordir=$("$here/config-export.sh" vendor)

cd "$root"

# Load paths, then the packages the tests need, then the test modules: a
# vendored package keeps its own name as a directory, so each one gets its own
# -L, exactly as the check suite does for lint.
set -- -L "$root" -L "$root/$submodule" -L "$root/$testdir" -L "$root/$vendordir"
for dir in "$root/$vendordir"/*/; do
  [ -d "$dir" ] || continue
  set -- "$@" -L "${dir%/}"
done
set -- "$@" \
  -l "$here/config.el" \
  -l "$here/lib/util.el" \
  -l "$here/lib/project.el" \
  -l "$here/deps.el" \
  --eval '(p/ensure-test-packages)'

found=0
for candidate in "$root/$testdir"/*.el; do
  [ -f "$candidate" ] || continue
  set -- "$@" -l "$candidate"
  found=1
done

if [ "$found" -eq 0 ]; then
  echo "no test modules found under $testdir/; skipping ERT"
  exit 0
fi

exec "$emacs_bin" -Q --batch \
  "$@" \
  --eval '(ert-run-tests-batch-and-exit)'
