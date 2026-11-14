#!/usr/bin/env bash
# Install the pinned controllers. The lab uses no interceptor, but the Triggers
# controller and webhook exit at start without the config-triggers-core-interceptors
# ConfigMap, which ships in interceptors.yaml.
set -euo pipefail
kubectl apply -f https://infra.tekton.dev/tekton-releases/pipeline/previous/v1.17.0/release.yaml >/dev/null
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-webhook --timeout=300s
kubectl -n tekton-pipelines-resolvers rollout status deploy/tekton-pipelines-remote-resolvers --timeout=300s
kubectl -n tekton-pipelines scale deploy/tekton-events-controller --replicas=0
kubectl apply -f https://infra.tekton.dev/tekton-releases/triggers/previous/v0.36.4/release.yaml >/dev/null
kubectl apply -f https://infra.tekton.dev/tekton-releases/triggers/previous/v0.36.4/interceptors.yaml >/dev/null
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-controller --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-webhook --timeout=300s
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-core-interceptors --timeout=300s
