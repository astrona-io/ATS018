#!/usr/bin/env bash
# Install Tekton Pipelines 1.17.0 and Tekton Triggers 0.36.4 with its core
# interceptors. The events controller is scaled to zero to save memory.
set -euo pipefail
kubectl apply -f https://infra.tekton.dev/tekton-releases/pipeline/previous/v1.17.0/release.yaml >/dev/null
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-webhook --timeout=300s
kubectl -n tekton-pipelines scale deploy/tekton-events-controller --replicas=0
kubectl apply -f https://infra.tekton.dev/tekton-releases/triggers/previous/v0.36.4/release.yaml >/dev/null
kubectl apply -f https://infra.tekton.dev/tekton-releases/triggers/previous/v0.36.4/interceptors.yaml >/dev/null
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-webhook --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-core-interceptors --timeout=300s
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
