#!/usr/bin/env bash
# Plumbing: start Gitea and create the admin user `platform`.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/gitea.yaml"
kubectl -n gitea rollout status deploy/gitea --timeout=300s
for i in $(seq 1 30); do
  if kubectl -n gitea exec deploy/gitea -- gitea admin user list >/dev/null 2>&1; then break; fi
  sleep 2
done
kubectl -n gitea exec deploy/gitea -- gitea admin user create --username platform \
  --password starfleet-gitops --email platform@starfleet.local --admin --must-change-password=false \
  >/dev/null 2>&1 || echo "[playground] Gitea user platform already exists"
