#!/usr/bin/env bash
# Creates the namespaces and the shuttle client. The broken Kustomize files
# are the material and ship in resources/scout; nothing is fixed here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/lab-start.yaml"
kubectl -n starfleet rollout status deploy/shuttle --timeout=180s
