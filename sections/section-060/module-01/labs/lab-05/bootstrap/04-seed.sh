#!/usr/bin/env bash
# Plumbing: push the public source repository into Gitea, add a push webhook
# that points at the EventSource Service, and install the broken pieces: the
# `run-tests` WorkflowTemplate (wrong working directory) and the Sensor (wrong
# branch filter, wrong commit field). The Role for workflow results has no
# RoleBinding (see lab-start.yaml).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/seed-repo.sh" scout-app "$SCRIPT_DIR/../repos/scout-app" public

LOCAL_PORT=$(( 30000 + RANDOM % 20000 ))
kubectl -n gitea port-forward svc/gitea-http "$LOCAL_PORT:3000" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT
API="http://127.0.0.1:$LOCAL_PORT/api/v1"
for i in $(seq 1 30); do curl -fs "$API/version" >/dev/null 2>&1 && break; sleep 1; done
curl -fs -u platform:starfleet-gitops -X POST -H 'Content-Type: application/json' \
  "$API/repos/starfleet/scout-app/hooks" \
  -d '{"type":"gitea","active":true,"events":["push"],"config":{"url":"http://push-webhook-eventsource-svc.argo-events.svc:12000/push","content_type":"json"}}' >/dev/null
echo "[lab] Added the push webhook to starfleet/scout-app"

kubectl apply -f "$SCRIPT_DIR/../manifests/workflowtemplate-run-tests.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/eventsource-push-webhook.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/sensor-push-ci.yaml"
