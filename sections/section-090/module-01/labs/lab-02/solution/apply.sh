#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
kubectl apply -f "$dir/flux.yaml"
kubectl -n flux-system wait kustomization/platform --for=condition=Ready --timeout=300s
kubectl -n starfleet-production wait scoutenvironments.platform.starfleet.dev/scout --for=create --timeout=180s
work=$(mktemp -d)
port=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$port:3000" >"$work/forward.log" 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true; rm -rf "$work"' EXIT
for attempt in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$port/api/v1/version" >/dev/null 2>&1; then break; fi
  sleep 1
done
git clone -q "http://platform:starfleet-gitops@127.0.0.1:$port/starfleet/platform-infra.git" "$work/source"
sed -i.bak 's/version: 6.99.0/version: 6.15.0/' "$work/source/environments/production/scoutenvironment.yaml"
rm "$work/source/environments/production/scoutenvironment.yaml.bak"
git -C "$work/source" -c user.name=platform -c user.email=platform@starfleet.local commit -qam "Use the published production version"
git -C "$work/source" push -q origin main
for attempt in $(seq 1 120); do
  revision=$(kubectl -n flux-system get gitrepository platform-infra -o jsonpath='{.status.artifact.revision}')
  commit=$(git -C "$work/source" rev-parse HEAD)
  [[ "$revision" == *"$commit" ]] && break
  sleep 3
done
kubectl -n flux-system wait kustomization/platform --for=condition=Ready --timeout=300s
kubectl -n flux-system wait kustomization/environments --for=condition=Ready --timeout=300s

bash "$dir/../validation/validate.sh" --wait
