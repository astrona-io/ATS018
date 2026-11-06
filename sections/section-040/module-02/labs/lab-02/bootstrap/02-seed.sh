#!/usr/bin/env bash
# Retry server-side dry runs until both admission webhooks accept the seed.
set -euo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Init runs before bootstrap.manifests, so create the namespace and accounts now.
kubectl apply -f "$LAB_DIR/manifests/lab-start.yaml"
for manifest in pipeline-scout-check.yaml listener-start.yaml; do
  ready=false
  for attempt in $(seq 1 60); do
    if kubectl apply --dry-run=server -f "$LAB_DIR/manifests/$manifest" >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 2
  done
  [[ "$ready" == true ]] || { echo "Admission webhook did not accept $manifest" >&2; exit 1; }
  kubectl apply -f "$LAB_DIR/manifests/$manifest"
  if [[ "$manifest" == pipeline-scout-check.yaml ]]; then
    # Save the admitted spec so grading can detect changes to the supplied Pipeline.
    original_spec=$(kubectl -n starfleet get pipeline scout-check -o jsonpath='{.spec}')
    kubectl -n starfleet create configmap scout-check-start \
      --from-literal="spec=$original_spec" --dry-run=client -o yaml | kubectl apply -f -
  fi
done
kubectl -n starfleet rollout status deploy/shuttle --timeout=180s
# The Triggers controller creates this Deployment asynchronously.
for attempt in $(seq 1 60); do
  if kubectl -n starfleet get deploy/el-scout-push >/dev/null 2>&1; then break; fi
  sleep 2
done
kubectl -n starfleet rollout status deploy/el-scout-push --timeout=180s
