#!/usr/bin/env bash
# Create genuine provider-managed objects and state only when the environment starts.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl -n starfleet rollout status deploy/shuttle --timeout=180s
# An earlier run on the same machine leaves its state and files here; start
# from the shipped working directories only.
rm -rf "$HOME/resources/tofu/scale" "$HOME/resources/tofu/expose" "$HOME/resources/tofu/drift"
mkdir -p "$HOME/resources/tofu"
cp -R "$SCRIPT_DIR/../resources/." "$HOME/resources/tofu/"
cd "$HOME/resources/tofu/scale"
# Flatten Astrona's current credentials; never select or hard-code a context.
umask 077
kubectl config view --raw --minify --flatten > kubeconfig
tofu init -input=false
tofu validate
tofu apply -input=false -auto-approve
python3 - <<'PYCODE'
from pathlib import Path
path = Path('deployment.tf')
path.write_text(path.read_text().replace('replicas = 1', 'replicas = 2'))
PYCODE
cd "$HOME/resources/tofu/expose"
# Flatten Astrona's current credentials; never select or hard-code a context.
umask 077
kubectl config view --raw --minify --flatten > kubeconfig
tofu init -input=false
tofu validate
tofu apply -input=false -auto-approve
cd "$HOME/resources/tofu/drift"
# Flatten Astrona's current credentials; never select or hard-code a context.
umask 077
kubectl config view --raw --minify --flatten > kubeconfig
tofu init -input=false
tofu validate
tofu apply -input=false -auto-approve
kubectl -n starfleet-production scale deployment/scout --replicas=1
kubectl -n starfleet-production rollout status deployment/scout --timeout=180s
