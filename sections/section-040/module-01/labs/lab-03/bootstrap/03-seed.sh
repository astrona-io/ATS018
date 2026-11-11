#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
kubectl apply -f "$dir/../manifests/lab-start.yaml"
bash "$dir/seed-repo.sh" scout-app "$dir/../repos/scout-app" public
kubectl create namespace tekton-tasks --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$dir/../manifests/task-fetch-source.yaml" -f "$dir/../manifests/pipeline.yaml"
