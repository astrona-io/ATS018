#!/usr/bin/env bash
# Plumbing: push both private repositories into Gitea, create the Argo CD
# Application `scout` and install the three Tasks. The Pipeline, the Git
# credentials and the service account are missing on purpose.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Init scripts run before bootstrap.manifests, so create the namespace here.
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
bash "$SCRIPT_DIR/seed-repo.sh" scout-app "$SCRIPT_DIR/../repos/scout-app"
bash "$SCRIPT_DIR/seed-repo.sh" scout-deploy "$SCRIPT_DIR/../repos/scout-deploy"
kubectl apply -f "$SCRIPT_DIR/../manifests/argocd-scout.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/task-fetch-source.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/task-publish-image.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/task-update-deploy.yaml"
for i in $(seq 1 60); do
  if kubectl -n starfleet get deploy scout >/dev/null 2>&1; then break; fi
  sleep 5
done
kubectl -n starfleet rollout status deploy/scout --timeout=300s
