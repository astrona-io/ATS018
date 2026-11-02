#!/usr/bin/env bash
# Install Argo Workflows v4.1.6 as a namespaced install into `starfleet`:
# the workflow controller watches only that namespace. The Argo server (web
# page and API) is not needed, so it is removed to save memory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Init scripts run before bootstrap.manifests, so create the namespace here.
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
# The CRDs are large, so apply server-side to avoid the annotation size limit.
kubectl apply --server-side --force-conflicts -n starfleet \
  -f https://github.com/argoproj/argo-workflows/releases/download/v4.1.6/namespace-install.yaml >/dev/null
kubectl -n starfleet delete deploy/argo-server svc/argo-server >/dev/null
kubectl -n starfleet rollout status deploy/workflow-controller --timeout=300s
