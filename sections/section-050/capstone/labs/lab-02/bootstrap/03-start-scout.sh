#!/usr/bin/env bash
# Create the namespaces and the shuttle client, then scout as a canary Rollout
# with a Gateway, an HTTPRoute and the PodMonitor. When scout is Healthy, apply
# the broken release setup (steps, analysis and AnalysisTemplate) over it. Needs the Rollout CRD and the
# plugin from step 1 and the Gateway API CRDs from the gatewayAPI addon.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/scout.yaml"
# The Gateway gets its address from the controller. shuttle reads it from the
# GATEWAY variable and sends steady requests to it, so Prometheus has traffic.
for attempt in $(seq 1 60); do
  GATEWAY_ADDRESS="$(kubectl -n starfleet get gateway scout-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
  [ -n "$GATEWAY_ADDRESS" ] && break
  sleep 5
done
[ -n "$GATEWAY_ADDRESS" ] || { echo "the Gateway got no address within 300 seconds" >&2; exit 1; }
kubectl -n starfleet set env deploy/shuttle GATEWAY="$GATEWAY_ADDRESS" >/dev/null
kubectl -n starfleet rollout status deploy/shuttle --timeout=120s
for attempt in $(seq 1 60); do
  phase="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [ "$phase" = "Healthy" ] && break
  sleep 5
done
[ "$phase" = "Healthy" ] || { echo "scout did not become Healthy within 300 seconds" >&2; exit 1; }
kubectl apply -f "$SCRIPT_DIR/../manifests/rollout-broken.yaml"
