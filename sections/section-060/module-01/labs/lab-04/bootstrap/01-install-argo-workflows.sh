#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Init scripts run before bootstrap.manifests, so create the namespaces here.
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"

# The manifest is large (it embeds the CRDs), so a client-side apply would
# overflow the last-applied annotation. Use server-side apply.
kubectl apply --server-side --force-conflicts -n starfleet \
  -f https://github.com/argoproj/argo-workflows/releases/download/v4.1.6/namespace-install.yaml >/dev/null

# Keep the web UI for the solution's UI path. auth-mode server lets the UI use
# the argo-server ServiceAccount, so no login token is needed; secure=false serves
# plain HTTP on the port-forward. Local lab only: never use these on a shared cluster.
kubectl -n starfleet patch deploy/argo-server --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--auth-mode=server"},
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--secure=false"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}]' >/dev/null
kubectl -n starfleet rollout status deploy/workflow-controller --timeout=300s
kubectl -n starfleet rollout status deploy/argo-server --timeout=300s
