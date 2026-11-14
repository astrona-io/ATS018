#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/seed-repo.sh" scout-deploy "$SCRIPT_DIR/../repos/scout-deploy"
kubectl -n gitea exec deploy/gitea -- gitea admin user create --username reader --password starfleet-readonly --email reader@starfleet.local --must-change-password=false
LOCAL_PORT=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$LOCAL_PORT:3000" >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
trap 'kill "$PORT_FORWARD_PID" 2>/dev/null || true' EXIT
for attempt in $(seq 1 30); do curl -fs "http://127.0.0.1:$LOCAL_PORT/api/v1/version" >/dev/null && break; sleep 1; done
curl -fs -u platform:starfleet-gitops -X PUT -H 'Content-Type: application/json' "http://127.0.0.1:$LOCAL_PORT/api/v1/repos/starfleet/scout-deploy/collaborators/reader" -d '{"permission":"read"}'
kubectl -n flux-system create secret generic scout-readonly --from-literal=username=reader --from-literal=password=starfleet-readonly
