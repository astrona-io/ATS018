#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.astrona/bin:$PATH"
helm history scout -n starfleet-production
helm rollback scout 2 -n starfleet-production --wait=watcher --timeout 180s
kubectl -n starfleet-production rollout status deploy/scout --timeout=180s
