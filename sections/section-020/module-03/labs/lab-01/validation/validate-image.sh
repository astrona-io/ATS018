#!/usr/bin/env bash
# scout-image: the fix belongs in Git. A manual image change would be reverted by self-heal.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
check_application scout-image image starfleet-image
manifest=$(git_file image/scout.yaml)
grep -q 'podinfo:6.15.0' <<<"$manifest" || fail "image/scout.yaml in Git does not use podinfo:6.15.0 - commit the fix"
echo "PASS: scout-image is fixed in Git and serves 6.15.0"
