#!/usr/bin/env bash
# Install Argo Events v1.9.11 as a namespaced install into `argo-events`, then
# the EventBus the sources and sensors use and the service account a Sensor
# runs as. No EventSource and no Sensor.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl create namespace argo-events --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply --server-side --force-conflicts -n argo-events \
  -f https://github.com/argoproj/argo-events/releases/download/v1.9.11/namespace-install.yaml >/dev/null
kubectl -n argo-events rollout status deploy/controller-manager --timeout=300s
kubectl apply -f "$SCRIPT_DIR/../manifests/eventbus.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/sensor-rbac.yaml"
