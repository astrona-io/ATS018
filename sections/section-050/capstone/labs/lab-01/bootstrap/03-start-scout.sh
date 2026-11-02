#!/usr/bin/env bash
# Create scout as a canary Rollout (needs the Rollout CRD from step 1)
# and the PodMonitor that lets Prometheus scrape every scout pod.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/scout.yaml"
for attempt in $(seq 1 60); do
  phase="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [ "$phase" = "Healthy" ] && exit 0
  sleep 5
done
echo "scout did not become Healthy within 300 seconds" >&2
exit 1
