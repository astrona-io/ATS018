#!/usr/bin/env bash
# Install Flux 2.9.6 from the release's install.yaml, which also holds the image
# reflector and image automation controllers. The Helm and source-watcher
# controllers are scaled to zero to save memory. The notification controller
# stays on: the other controllers wait for their events to be delivered to it,
# and with it off every status update is delayed by about a minute.
set -euo pipefail
kubectl apply --server-side -f https://github.com/fluxcd/flux2/releases/download/v2.9.6/install.yaml >/dev/null
kubectl -n flux-system scale deploy/helm-controller deploy/source-watcher --replicas=0
for controller in source-controller kustomize-controller notification-controller image-reflector-controller image-automation-controller; do
  kubectl -n flux-system rollout status deploy/$controller --timeout=300s
done
