#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
kubectl apply -f "$dir/application.yaml"

bash "$dir/../validation/validate.sh" --wait
