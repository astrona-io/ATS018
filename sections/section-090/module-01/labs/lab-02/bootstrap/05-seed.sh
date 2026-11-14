#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
bash "$dir/seed-repo.sh" platform-infra "$dir/../repos/platform-infra"
kubectl -n flux-system create secret generic platform-infra-auth \
  --from-literal=username=platform --from-literal=password=starfleet-gitops \
  --dry-run=client -o yaml | kubectl apply -f -
