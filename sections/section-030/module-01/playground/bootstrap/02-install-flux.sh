#!/usr/bin/env bash
set -euo pipefail
flux install --version=v2.9.6 --components=source-controller,kustomize-controller,helm-controller,notification-controller
kubectl -n flux-system rollout status deploy/source-controller --timeout=300s
kubectl -n flux-system rollout status deploy/kustomize-controller --timeout=300s
kubectl -n flux-system rollout status deploy/helm-controller --timeout=300s
kubectl -n flux-system rollout status deploy/notification-controller --timeout=300s
