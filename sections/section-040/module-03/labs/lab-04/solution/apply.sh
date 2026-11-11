#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
export PATH="$HOME/.astrona/bin:$PATH"
kubectl apply -f "$dir/workflowtemplate.yaml"
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.15.0 \
  -p name=scout -p namespace=outpost -p task=release-check --wait

argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.14.0 \
  -p name=probe -p namespace=starfleet -p task=preview-check --wait
bash "$dir/../validation/validate.sh" --wait
