#!/usr/bin/env bash
# sign-sums.sh <sums file> <release tag>: <sums file>.minisig for the in-app updaters (see minisign.mjs).
# The signed trusted comment names the tag, so the apps refuse this signature on any other release.
# Without the secret UPDATE_SIGNING_KEY the release goes out unsigned with a warning (apps from Hivogram build 9 /
# Lite build 5 on will refuse to install it).
set -euo pipefail
file=$1
tag=$2
[[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "::error::Bad tag '$tag'"; exit 1; }
if [ -z "${UPDATE_SIGNING_KEY:-}" ]; then
  echo "::warning::Secret UPDATE_SIGNING_KEY is not set: $file is NOT signed, updated apps will refuse this release"
  exit 0
fi
node "$(dirname "$0")/minisign.mjs" "$file" "$(printf 'timestamp:%s\tfile:%s\ttag:%s' "$(date +%s)" "$(basename "$file")" "$tag")"
