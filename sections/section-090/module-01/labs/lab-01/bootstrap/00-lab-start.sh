#!/usr/bin/env bash
# Init scripts run before the manifest stage, so the namespaces and the client
# pod are created here.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml" >/dev/null
