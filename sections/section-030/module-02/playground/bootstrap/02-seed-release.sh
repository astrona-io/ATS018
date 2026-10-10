#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/release.yaml"
kubectl -n starfleet wait helmrelease/scout --for=condition=Ready --timeout=300s
kubectl -n starfleet patch helmrelease scout --type=merge -p '{"spec":{"values":{"faults":{"unready":true}}}}'
for attempt in $(seq 1 90); do
  REASON="$(kubectl -n starfleet get helmrelease scout -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}')"
  if [ "$REASON" = UpgradeFailed ]; then exit 0; fi
  sleep 2
done
printf '%s\n' 'Expected UpgradeFailed starting state was not reached' >&2
exit 1
