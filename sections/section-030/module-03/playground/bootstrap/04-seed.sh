#!/usr/bin/env bash
# Plumbing: push starfleet/scout-deploy into Gitea, create the read-write Git
# credential Secret, and start the Flux delivery of scout 6.14.0. Deliberately
# absent: no ImageRepository, ImagePolicy or ImageUpdateAutomation.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Init scripts run before bootstrap.manifests, so create the namespaces here.
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
bash "$SCRIPT_DIR/seed-repo.sh" scout-deploy "$SCRIPT_DIR/../repos/scout-deploy"
kubectl -n flux-system create secret generic scout-git \
  --from-literal=username=platform --from-literal=password=starfleet-gitops
kubectl apply -f "$SCRIPT_DIR/../manifests/flux-delivery.yaml"
for attempt in $(seq 1 60); do
  if kubectl -n starfleet get deploy scout >/dev/null 2>&1; then break; fi
  sleep 3
done
kubectl -n starfleet rollout status deploy/scout --timeout=300s
