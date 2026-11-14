#!/usr/bin/env bash
# scout-path: the fix is in the Application (its path), checked by behaviour.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
check_application scout-path path starfleet-path
echo "PASS: scout-path syncs the folder 'path' and serves 6.15.0"
