#!/usr/bin/env bash
# Create genuine provider-managed objects and state only when the environment starts.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl -n starfleet rollout status deploy/shuttle --timeout=180s
mkdir -p "$HOME/resources/tofu"
cp -R "$SCRIPT_DIR/../resources/." "$HOME/resources/tofu/"
cd "$HOME/resources/tofu/scout"
# Flatten Astrona's current credentials; never select or hard-code a context.
umask 077
kubectl config view --raw --minify --flatten > kubeconfig
tofu init -input=false
tofu validate
tofu apply -input=false -auto-approve
