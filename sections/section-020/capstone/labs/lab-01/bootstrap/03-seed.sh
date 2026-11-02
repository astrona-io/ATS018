#!/usr/bin/env bash
# Plumbing: push the module's repositories into Git and give Argo CD one
# credential template for every repository of the `starfleet` organisation.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/seed-repo.sh" platform-apps "$SCRIPT_DIR/../repos/platform-apps"
bash "$SCRIPT_DIR/seed-repo.sh" outpost-apps "$SCRIPT_DIR/../repos/outpost-apps"
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: creds-starfleet-org
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: http://gitea-http.gitea.svc:3000/starfleet
  username: platform
  password: starfleet-gitops
YAML

# The broken Application: its image tag does not exist and it has no automated sync.
kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: probe
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
    targetRevision: main
    path: apps/probe
  destination:
    server: https://kubernetes.default.svc
    namespace: starfleet
YAML
kubectl -n argocd wait --for=create application/probe --timeout=60s
# One manual sync, so the broken Deployment is created.
kubectl -n argocd patch application probe --type merge -p '{"operation":{"sync":{}}}'
