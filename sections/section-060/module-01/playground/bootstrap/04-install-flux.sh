#!/usr/bin/env bash
# Plumbing: install Flux 2.9.6 from the release's install.yaml and keep only the
# source, kustomize and notification controllers. The notification controller
# stays on: with it off every status update is delayed by about a minute.
set -euo pipefail
kubectl apply --server-side -f https://github.com/fluxcd/flux2/releases/download/v2.9.6/install.yaml >/dev/null
kubectl -n flux-system scale deploy/helm-controller deploy/source-watcher \
  deploy/image-reflector-controller deploy/image-automation-controller --replicas=0
for controller in source-controller kustomize-controller notification-controller; do
  kubectl -n flux-system rollout status deploy/$controller --timeout=300s
done
