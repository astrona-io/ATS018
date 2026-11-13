#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/secret-repo-scout-deploy.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: repo-scout-deploy
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
  username: platform
  password: starfleet-gitops
YAML
cat > "$WORK/application-scout-staging.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
    targetRevision: main
    path: overlays/staging
  destination:
    server: https://kubernetes.default.svc
    namespace: starfleet-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML

kubectl apply -f "$WORK/secret-repo-scout-deploy.yaml"
kubectl apply -f "$WORK/application-scout-staging.yaml"
kubectl -n starfleet-staging wait --for=create deploy/scout --timeout=180s
kubectl -n starfleet-staging rollout status deploy/scout --timeout=180s
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/scout-staging --timeout=180s
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/scout-staging --timeout=180s
