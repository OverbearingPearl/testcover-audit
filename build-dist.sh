#!/bin/sh
# Build release artifacts from the current commit, using git archive so the
# archive is exactly the tree at HEAD.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$here/..")
package=$("$here/config-export.sh" package)
version=$("$here/config-export.sh" version)

[ -n "$version" ] || {
  echo "no Version header found in the main file" >&2
  exit 1
}

cd "$root"

git rev-parse --verify HEAD >/dev/null 2>&1 || {
  echo "refusing to build release artifacts: there is no commit yet" >&2
  exit 1
}

# The archive is built from HEAD, so an uncommitted main file would
# silently produce a release without the package in it.
main=$("$here/config-export.sh" main)
git cat-file -e "HEAD:$main" 2>/dev/null || {
  echo "refusing to build release artifacts: $main is not committed at HEAD" >&2
  exit 1
}

mkdir -p dist
prefix="$package-$version"

git archive --format=tar.gz --prefix="$prefix/" \
  -o "dist/$prefix.tar.gz" HEAD
git archive --format=zip --prefix="$prefix/" \
  -o "dist/$prefix.zip" HEAD

if command -v sha256sum >/dev/null 2>&1; then
  (cd dist && sha256sum "$prefix.tar.gz" "$prefix.zip" > SHA256SUMS)
else
  (cd dist && shasum -a 256 "$prefix.tar.gz" "$prefix.zip" > SHA256SUMS)
fi

ls -l dist
