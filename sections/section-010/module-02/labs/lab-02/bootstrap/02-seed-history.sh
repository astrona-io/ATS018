#!/usr/bin/env bash
# Seed the release history for the independent recovery exercise.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../solution" && pwd)"
mkdir -p "$HOME/resources"
# Start with a clean release history on a fresh lab.
cp -R "$SCRIPT_DIR/../resources/scout" "$HOME/resources/scout-initial"
helm install scout "$HOME/resources/scout-initial" -n starfleet-production --wait=watcher --timeout 180s
rm -rf "$HOME/resources/scout"
cp -R "$SCRIPT_DIR/scout" "$HOME/resources/scout"
cp "$SCRIPT_DIR/production-values.yaml" "$HOME/resources/production-values.yaml"
helm lint "$HOME/resources/scout" -f "$HOME/resources/production-values.yaml"
helm template scout "$HOME/resources/scout" -n starfleet-production -f "$HOME/resources/production-values.yaml" >/dev/null
helm upgrade --install scout "$HOME/resources/scout" -n starfleet-production --create-namespace -f "$HOME/resources/production-values.yaml" --wait=watcher --timeout 180s
helm upgrade --install scout "$HOME/resources/scout" -n starfleet-production -f "$HOME/resources/production-values.yaml" --set message=temporary --wait=watcher --timeout 180s
