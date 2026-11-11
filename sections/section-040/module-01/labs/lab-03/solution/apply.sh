#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
RUN=$(kubectl create -f "$dir/run.yaml" -o name)
kubectl -n starfleet wait "$RUN" --for=jsonpath='{.status.conditions[0].status}'=False --timeout=120s
kubectl apply -f "$dir/pipeline.yaml"
RUN=$(kubectl create -f "$dir/run.yaml" -o name)
kubectl -n starfleet wait "$RUN" --for=condition=Succeeded --timeout=240s

bash "$dir/../validation/validate.sh" --wait
