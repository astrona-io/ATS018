#!/usr/bin/env bash
# Plumbing: create the organisation `starfleet` and push a folder as a private
# repository. Usage: seed-repo.sh <repository name> <folder>
set -euo pipefail
REPO="$1"; SRC="$2"
AUTH="platform:starfleet-gitops"
LOCAL_PORT=$(( 30000 + RANDOM % 20000 ))
kubectl -n gitea port-forward svc/gitea-http "$LOCAL_PORT:3000" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true; rm -rf "${WORK:-}"' EXIT
API="http://127.0.0.1:$LOCAL_PORT/api/v1"
for i in $(seq 1 30); do curl -fs "$API/version" >/dev/null 2>&1 && break; sleep 1; done
curl -fs -u "$AUTH" -X POST -H 'Content-Type: application/json' "$API/orgs" \
  -d '{"username":"starfleet","visibility":"public"}' >/dev/null || true
curl -fs -u "$AUTH" -X POST -H 'Content-Type: application/json' "$API/orgs/starfleet/repos" \
  -d "{\"name\":\"$REPO\",\"private\":true,\"default_branch\":\"main\"}" >/dev/null || true
WORK="$(mktemp -d)"
cp -R "$SRC/." "$WORK/"
cd "$WORK"
git init -q -b main
git -c user.name=platform -c user.email=platform@starfleet.local add -A
git -c user.name=platform -c user.email=platform@starfleet.local commit -q -m "Initial content of $REPO"
git push -q "http://$AUTH@127.0.0.1:$LOCAL_PORT/starfleet/$REPO.git" main
echo "[playground] Seeded starfleet/$REPO"
