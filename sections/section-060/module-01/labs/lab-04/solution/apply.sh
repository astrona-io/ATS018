#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
export PATH="$HOME/.astrona/bin:$PATH"
kubectl apply -f "$dir/workflowtemplate.yaml"
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=alpine:3.23 -p name=scout -p namespace=outpost \
  -p msg="scout is running" --wait
for check in template runs deployments; do
  bash "$dir/../validation/validate-$check.sh" --wait
done
