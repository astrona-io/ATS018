#!/usr/bin/env bash
# Install Flux 2.9.6 from the release's install.yaml. The flux command-line tool
# on the machine can be newer and refuses `flux install --version=v2.9.6`. The
# image controllers and the source-watcher are not used here, so they are scaled
# to zero to save memory.
set -euo pipefail
kubectl apply --server-side -f https://github.com/fluxcd/flux2/releases/download/v2.9.6/install.yaml >/dev/null
kubectl -n flux-system scale deploy/image-reflector-controller deploy/image-automation-controller deploy/source-watcher --replicas=0
for controller in source-controller kustomize-controller helm-controller notification-controller; do
  kubectl -n flux-system rollout status deploy/$controller --timeout=300s
done
