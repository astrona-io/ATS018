#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
kubectl apply -f "$dir/../manifests/canary.yaml"
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Initialized --timeout=240s
kubectl -n starfleet rollout status deploy/scout-primary --timeout=180s
