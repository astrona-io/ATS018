#!/usr/bin/env bash
# Creates the starting Flux objects. They are broken on purpose and are the
# material of the lab; nothing is fixed here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/flux-start.yaml"
