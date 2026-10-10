#!/usr/bin/env bash
# Create scout as a blue/green Rollout (needs the Rollout CRD from step 1)
# and the PodMonitor that lets Prometheus scrape every scout pod.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/scout.yaml"
for i in $(seq 1 60); do
  phase="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [ "$phase" = "Healthy" ] && break
  sleep 5
done
