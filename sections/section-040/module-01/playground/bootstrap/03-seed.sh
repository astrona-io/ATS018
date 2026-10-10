#!/usr/bin/env bash
# Plumbing: push the public source repository into Gitea, then install the
# broken `run-tests` Task the learner diagnoses.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Init scripts run before bootstrap.manifests, so create the namespace here.
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
bash "$SCRIPT_DIR/seed-repo.sh" scout-app "$SCRIPT_DIR/../repos/scout-app" public
kubectl apply -f "$SCRIPT_DIR/../manifests/task-run-tests.yaml"
