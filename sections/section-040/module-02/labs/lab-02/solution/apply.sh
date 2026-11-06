#!/usr/bin/env bash
set -euo pipefail
SOLUTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SOLUTION_DIR/triggerbinding-scout-push.yaml"
kubectl apply -f "$SOLUTION_DIR/triggertemplate-scout-check.yaml"
kubectl apply -f "$SOLUTION_DIR/rolebinding-scout-listener-runs.yaml"
kubectl apply -f "$SOLUTION_DIR/eventlistener-scout-push.yaml"
kubectl -n starfleet rollout status deploy/el-scout-push --timeout=180s
# Restart the sink after updating its configuration, so its caches load the new objects.
kubectl -n starfleet rollout restart deploy/el-scout-push
kubectl -n starfleet rollout status deploy/el-scout-push --timeout=180s
response=$(kubectl -n starfleet exec deploy/shuttle -- curl --fail-with-body --silent --show-error --max-time 20 \
  -H 'Content-Type: application/json' \
  -d '{"ref":"refs/heads/main","repository":{"full_name":"starfleet/scout-app"}}' \
  http://el-scout-push.starfleet.svc:8080)
event_id=$(printf '%s' "$response" | sed -n 's/.*"eventID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[[ "$event_id" =~ ^[a-f0-9-]{36}$ ]] || { echo 'No eventID in listener response' >&2; exit 1; }
# Wait only for the run created by this request.
for attempt in $(seq 1 60); do
  run_name=$(kubectl -n starfleet get pipelineruns.tekton.dev \
    -l "triggers.tekton.dev/eventlistener=scout-push,triggers.tekton.dev/triggers-eventid=$event_id" \
    -o jsonpath='{.items[*].metadata.name}')
  if [[ -n "$run_name" ]]; then
    kubectl -n starfleet wait --for=condition=Succeeded "pipelinerun/$run_name" --timeout=120s
    exit 0
  fi
  sleep 2
done
echo 'The student request did not create a run' >&2
exit 1
