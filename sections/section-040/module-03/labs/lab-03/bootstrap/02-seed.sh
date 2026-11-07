#!/usr/bin/env bash
# Installs the WorkflowTemplate shuttle-release and leaves one Succeeded run of its three-step version.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.astrona/bin:$PATH"
# Use the Kubernetes API through the kubeconfig, even when the host points at an Argo Server.
unset ARGO_SERVER ARGO_TOKEN

kubectl apply -f "$SCRIPT_DIR/../manifests/workflowtemplates.yaml"

NAME="$(argo submit -n starfleet --from workflowtemplate/shuttle-release -o name)"
kubectl -n starfleet wait "workflow/$NAME" --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s
