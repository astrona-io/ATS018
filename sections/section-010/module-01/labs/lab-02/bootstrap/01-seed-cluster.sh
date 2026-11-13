#!/usr/bin/env bash
# Prepare namespaces and the request client; leave every graded workload absent.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl -n starfleet rollout status deploy/shuttle --timeout=180s
mkdir -p "$HOME/resources"
cp -R "$SCRIPT_DIR/../resources/." "$HOME/resources/"
