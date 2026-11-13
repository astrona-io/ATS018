#!/usr/bin/env bash
# scout-reject: the fix belongs in Git. The live object must come from Git, not from a manual edit.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
check_application scout-reject reject starfleet-reject
manifest=$(git_file reject/scout.yaml)
grep -q 'containerPort: 99999' <<<"$manifest" && fail "reject/scout.yaml in Git still has containerPort 99999 - commit the fix"
grep -q 'containerPort: 9898' <<<"$manifest" || fail "reject/scout.yaml in Git does not set containerPort 9898"
echo "PASS: scout-reject is fixed in Git and serves 6.15.0"
