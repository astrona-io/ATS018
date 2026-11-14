#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
port=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$port:3000" >"$work/forward.log" 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true; rm -rf "$work"' EXIT
for attempt in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$port/api/v1/version" >/dev/null 2>&1; then break; fi
  sleep 1
done
git clone -q "http://platform:starfleet-gitops@127.0.0.1:$port/starfleet/scout-faults.git" "$work/source"
cp "$dir/migrate.yaml" "$dir/settings.yaml" "$dir/kustomization.yaml" "$work/source/path/"
git -C "$work/source" add path
git -C "$work/source" -c user.name=platform -c user.email=platform@starfleet.local commit -qm "Run migration before the settings wave"
git -C "$work/source" push -q origin main
kubectl -n argocd annotate application scout-path argocd.argoproj.io/refresh=hard --overwrite

bash "$dir/../validation/validate.sh" --wait
