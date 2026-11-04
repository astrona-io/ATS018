#!/usr/bin/env bash
# Reference solution; never invoked during ordinary bootstrap.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/resources"
rm -rf "$HOME/resources/scout"
cp -R "$SCRIPT_DIR/scout" "$HOME/resources/scout"
cp "$SCRIPT_DIR/production-values.yaml" "$HOME/resources/production-values.yaml"
helm lint "$HOME/resources/scout" -f "$HOME/resources/production-values.yaml"
helm template scout "$HOME/resources/scout" -n starfleet-production -f "$HOME/resources/production-values.yaml" >/dev/null
helm upgrade --install scout "$HOME/resources/scout" -n starfleet-production --create-namespace -f "$HOME/resources/production-values.yaml" --wait=watcher --timeout 180s
rm -rf "$HOME/resources/scout-overlay"
cp -R "$SCRIPT_DIR/scout-overlay" "$HOME/resources/scout-overlay"
kubectl apply -k "$HOME/resources/scout-overlay/overlays/staging"
kubectl -n starfleet-staging rollout status deploy/scout --timeout=180s
kubectl -n starfleet-production rollout status deploy/scout --timeout=180s
