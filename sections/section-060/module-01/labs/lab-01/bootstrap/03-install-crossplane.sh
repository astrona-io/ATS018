#!/usr/bin/env bash
# Plumbing: install Crossplane 2.4.3 with its Helm chart. Only the core
# controller and the RBAC manager run. No provider and no function is installed:
# the learner installs them with Provider and Function objects.
set -euo pipefail
CROSSPLANE_VERSION="2.4.3"
helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1 || true
helm repo update crossplane-stable >/dev/null
helm upgrade --install crossplane crossplane-stable/crossplane \
  --version "$CROSSPLANE_VERSION" \
  --namespace crossplane-system --create-namespace \
  --wait --timeout 5m >/dev/null
kubectl -n crossplane-system rollout status deploy/crossplane --timeout=300s
kubectl -n crossplane-system rollout status deploy/crossplane-rbac-manager --timeout=300s
