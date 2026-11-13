#!/usr/bin/env bash
# Reference solution; never invoked during ordinary bootstrap.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/resources"
rm -rf "$HOME/resources/scout"
cp -R "$SCRIPT_DIR/scout" "$HOME/resources/scout"
kubectl apply -k "$HOME/resources/scout/overlays/staging"
kubectl -n starfleet-staging rollout status deploy/scout --timeout=180s
