#!/usr/bin/env bash
# Install Argo CD 3.5.4 (non-HA). Dex and the notifications controller are
# scaled to zero to save memory; this playground needs neither.
set -euo pipefail
ARGOCD_VERSION="v3.5.4"
kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" >/dev/null
kubectl -n argocd scale deploy/argocd-dex-server deploy/argocd-notifications-controller --replicas=0
for d in argocd-server argocd-repo-server argocd-redis argocd-applicationset-controller; do
  kubectl -n argocd rollout status deploy/$d --timeout=300s
done
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
