#!/usr/bin/env bash
# Installs the two WorkflowTemplates and leaves one failed run of scout-check to read.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.astrona/bin:$PATH"
# Use the Kubernetes API through the kubeconfig, even when the host points at an Argo Server.
unset ARGO_SERVER ARGO_TOKEN

kubectl apply -f "$SCRIPT_DIR/../manifests/workflowtemplates.yaml"

NAME="$(argo submit -n starfleet --from workflowtemplate/scout-check -o name)"
kubectl -n starfleet wait "workflow/$NAME" --for=jsonpath='{.status.phase}'=Failed --timeout=300s
