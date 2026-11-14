#!/usr/bin/env bash
# Installs the Tasks and the Pipeline, then leaves one failed PipelineRun to read.
# The run fails on purpose: it uses the ServiceAccount default, which has no rights.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Init scripts run before bootstrap.manifests, so create the namespace here.
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/tasks-outpost-onboard.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/pipeline-outpost-onboard.yaml"
kubectl apply -f "$SCRIPT_DIR/../manifests/pipelinerun-first-try.yaml"
kubectl -n starfleet wait pipelinerun/outpost-onboard-first-try --for=condition=Succeeded=False --timeout=300s
