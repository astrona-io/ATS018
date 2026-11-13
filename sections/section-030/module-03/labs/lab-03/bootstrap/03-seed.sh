#!/usr/bin/env bash
# Seed the repository credentials and the healthy Application.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/seed-repo.sh" scout-faults "$SCRIPT_DIR/../repos/scout-faults"
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
kubectl apply -f "$SCRIPT_DIR/../manifests/applications.yaml"

kubectl -n argocd wait application/scout-path --for=jsonpath='{.status.health.status}'=Healthy --timeout=180s
kubectl -n argocd wait application/scout-path --for=jsonpath='{.status.sync.status}'=Synced --timeout=180s
