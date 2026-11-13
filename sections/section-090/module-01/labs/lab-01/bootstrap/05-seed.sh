#!/usr/bin/env bash
# Plumbing: push the module's repository content into Gitea.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/seed-repo.sh" platform-infra "$SCRIPT_DIR/../repos/platform-infra"

# Plumbing: repository credentials for Argo CD, so the task can focus on the delivery.
kubectl -n argocd apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: repo-platform-infra
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git
  username: platform
  password: starfleet-gitops
YAML
