#!/usr/bin/env bash
set -euo pipefail
VALIDATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$VALIDATION_DIR/run-checks.sh"
run_names=$(kubectl -n starfleet get pipelineruns -l 'triggers.tekton.dev/eventlistener=scout-push,triggers.tekton.dev/trigger=push' -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
for run_name in $run_names; do
  if run_matches "$run_name" refs/heads/main starfleet/scout-app; then
    echo 'PASS: student-request'
    exit 0
  fi
done
echo 'FAIL: student-request — send the main/scout-app request from shuttle and wait for its run to succeed'
exit 1
