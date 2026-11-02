#!/usr/bin/env bash
# Install the Argo Rollouts 1.10.0 controller in the namespace argo-rollouts.
# No dashboard, no traffic router and no metrics provider.
set -euo pipefail
kubectl get namespace argo-rollouts >/dev/null 2>&1 || kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts --server-side --force-conflicts \
  -f https://github.com/argoproj/argo-rollouts/releases/download/v1.10.0/install.yaml >/dev/null
kubectl -n argo-rollouts rollout status deploy/argo-rollouts --timeout=300s
