#!/usr/bin/env bash
# Plumbing: push scout-faults into Git, give Argo CD the credentials, and
# create the four broken Applications.
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
