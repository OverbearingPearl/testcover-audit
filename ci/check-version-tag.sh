#!/bin/sh
# Fail unless the release tag matches the Version header in the main file.
# Usage: ci/check-version-tag.sh [TAG]   (defaults to $GITHUB_REF_NAME)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
tag=${1:-${GITHUB_REF_NAME:-}}
version=$("$here/config-export.sh" version)

[ -n "$tag" ] || { echo "no tag given and GITHUB_REF_NAME is unset" >&2; exit 1; }

# Accept both v1.2.3 and 1.2.3 tags.
if [ "${tag#v}" != "$version" ]; then
  echo "tag $tag does not match Version: $version" >&2
  exit 1
fi

echo "release tag $tag matches Version: $version"
