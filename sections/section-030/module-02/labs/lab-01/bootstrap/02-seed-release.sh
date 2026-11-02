#!/usr/bin/env bash
# Installs the release, then breaks it on purpose (the pods never become ready)
# and records the uid of the HelmRelease so the grader can tell a repair from a
# delete and recreate.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/release.yaml"
kubectl -n starfleet wait helmrelease/scout --for=condition=Ready --timeout=300s
UID_BEFORE="$(kubectl -n starfleet get helmrelease scout -o jsonpath='{.metadata.uid}')"
kubectl -n starfleet create configmap lab-baseline --from-literal=helmrelease-uid="$UID_BEFORE" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n starfleet patch helmrelease scout --type=merge -p '{"spec":{"values":{"faults":{"unready":true}}}}'
for attempt in $(seq 1 90); do
  REASON="$(kubectl -n starfleet get helmrelease scout -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}')"
  if [ "$REASON" = UpgradeFailed ]; then exit 0; fi
  sleep 2
done
printf '%s\n' 'Expected UpgradeFailed starting state was not reached' >&2
exit 1
