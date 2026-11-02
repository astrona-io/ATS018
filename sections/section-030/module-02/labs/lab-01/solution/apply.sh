#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: scout
  namespace: starfleet
spec:
  interval: 1m
  timeout: 30s
  chartRef:
    kind: OCIRepository
    name: podinfo
  values:
    replicaCount: 1
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        memory: 128Mi
    faults:
      unready: false
  upgrade:
    remediation:
      retries: 1
      remediateLastFailure: true
      strategy: rollback
YAML

STAMP="$(date +%s)"
kubectl -n starfleet annotate helmrelease/scout --overwrite \
  "reconcile.fluxcd.io/requestedAt=$STAMP" "reconcile.fluxcd.io/resetRequestedAt=$STAMP"
kubectl -n starfleet wait helmrelease/scout --for=condition=Ready --timeout=240s
