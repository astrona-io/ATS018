#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
kubectl apply -f "$dir/applicationset.yaml"
work=$(mktemp -d)
port=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$port:3000" >"$work/forward.log" 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true; rm -rf "$work"' EXIT
for attempt in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$port/api/v1/version" >/dev/null 2>&1; then break; fi
  sleep 1
done
git clone -q "http://platform:starfleet-gitops@127.0.0.1:$port/starfleet/platform-apps.git" "$work/source"
mkdir "$work/source/apps/beacon"
sed 's/probe/beacon/g' "$work/source/apps/probe/deployment.yaml" > "$work/source/apps/beacon/deployment.yaml"
cp "$work/source/apps/probe/kustomization.yaml" "$work/source/apps/beacon/"
git -C "$work/source" add apps/beacon
git -C "$work/source" -c user.name=platform -c user.email=platform@starfleet.local commit -qm "Add beacon"
git -C "$work/source" push -q origin main
kubectl -n argocd annotate applicationset platform-apps argocd.argoproj.io/application-set-refresh=true --overwrite

bash "$dir/../validation/validate.sh" --wait
