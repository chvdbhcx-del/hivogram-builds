#!/usr/bin/env bash
# sign-sums.sh <sums file> <release tag>: <sums file>.minisig for the in-app updaters (see minisign.mjs).
# The signed trusted comment names the tag, so the apps refuse this signature on any other release.
# Every release must be signed: apps from Hivogram build 9 / Lite build 5 on refuse an unsigned one. So without the
# secret UPDATE_SIGNING_KEY, or when signing fails, this fails, and the release step with it (nothing is published).
# Test builds (Hivogram with publish = false) publish nothing and do not call this.
set -euo pipefail
file=$1
tag=$2
[[ "$tag" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "::error::Bad tag '$tag'"; exit 1; }
if [ -z "${UPDATE_SIGNING_KEY:-}" ]; then
  echo "::error::Secret UPDATE_SIGNING_KEY is not set: $file cannot be signed, nothing is published (updated apps refuse unsigned releases)"
  exit 1
fi
node "$(dirname "$0")/minisign.mjs" "$file" "$(printf 'timestamp:%s\tfile:%s\ttag:%s' "$(date +%s)" "$(basename "$file")" "$tag")"
[ -s "$file.minisig" ] || { echo "::error::$file.minisig was not written"; exit 1; }
