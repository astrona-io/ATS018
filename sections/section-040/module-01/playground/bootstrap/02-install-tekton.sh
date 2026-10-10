#!/usr/bin/env bash
# Install Tekton Pipelines 1.17.0 (controller, webhook, events controller and
# the remote resolvers). No Triggers and no Dashboard.
set -euo pipefail
kubectl apply -f https://infra.tekton.dev/tekton-releases/pipeline/previous/v1.17.0/release.yaml >/dev/null
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-webhook --timeout=300s
kubectl -n tekton-pipelines-resolvers rollout status deploy/tekton-pipelines-remote-resolvers --timeout=300s
# The validating webhook must answer before the seed step creates a Task.
for i in $(seq 1 30); do
  if kubectl create --dry-run=server -f - >/dev/null 2>&1 <<'TASK'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: webhook-ready
  namespace: default
spec:
  steps:
    - name: noop
      image: alpine:3.23
      script: "true"
TASK
  then break; fi
  sleep 2
done
