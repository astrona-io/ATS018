#!/usr/bin/env bash
set -euo pipefail
VALIDATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$VALIDATION_DIR/run-checks.sh"
fail() { echo "FAIL: event-runs — $*"; exit 1; }
# Unique values prevent a previous run or hard-coded template from passing.
request_dir=$(mktemp -d)
request_token=$(basename "$request_dir" | tr '[:upper:]' '[:lower:]')
event_selectors=''
cleanup() {
  # Delete only runs created by this invocation, so watch does not fill the cluster.
  for selector in $event_selectors; do
    kubectl -n starfleet delete pipelineruns -l "$selector" --wait=false >/dev/null 2>&1 || true
  done
  rm -rf "$request_dir"
}
trap cleanup EXIT
for sample in one two; do
  revision="refs/heads/probe-$request_token-$sample"
  repository="starfleet/probe-$request_token-$sample"
  response=$(kubectl -n starfleet exec deploy/shuttle -- curl --fail-with-body --silent --show-error --max-time 15 \
    -H 'Content-Type: application/json' \
    -d "{\"ref\":\"$revision\",\"repository\":{\"full_name\":\"$repository\"}}" \
    http://el-scout-push.starfleet.svc:8080) || fail 'request to the listener Service failed'
  event_id=$(printf '%s' "$response" | sed -n 's/.*"eventID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [[ "$event_id" =~ ^[a-f0-9-]{36}$ ]] || fail 'listener response has no eventID'
  selector="triggers.tekton.dev/eventlistener=scout-push,triggers.tekton.dev/trigger=push,triggers.tekton.dev/triggers-eventid=$event_id"
  event_selectors="$event_selectors $selector"
  run_name=''
  for attempt in $(seq 1 30); do
    run_name=$(kubectl -n starfleet get pipelineruns -l "$selector" -o jsonpath='{.items[*].metadata.name}')
    [[ -z "$run_name" ]] || break
    sleep 1
  done
  [[ -n "$run_name" && "$run_name" != *' '* ]] || fail 'request must create exactly one new PipelineRun'
  kubectl -n starfleet wait --for=condition=Succeeded "pipelinerun/$run_name" --timeout=90s || fail "$run_name did not succeed"
  run_matches "$run_name" "$revision" "$repository" || fail "$run_name did not deliver both payload params as scout-runner"
done
echo 'PASS: event-runs'
