#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Init scripts run before bootstrap.manifests, so create the namespaces here.
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"

# The manifest is large (it embeds the CRDs), so a client-side apply would
# overflow the last-applied annotation. Use server-side apply.
kubectl apply --server-side --force-conflicts -n starfleet \
  -f https://github.com/argoproj/argo-workflows/releases/download/v4.1.6/namespace-install.yaml >/dev/null

# The argo command-line tool talks to the Kubernetes API, so the web server can go.
kubectl -n starfleet delete deploy/argo-server svc/argo-server >/dev/null
kubectl -n starfleet rollout status deploy/workflow-controller --timeout=300s
