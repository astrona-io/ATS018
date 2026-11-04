#!/usr/bin/env bash
# Creates the starting Flux objects. They are broken on purpose and are the
# material of the lab; nothing is fixed here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/flux-start.yaml"

# Let Flux deliver scout-production once, so its objects and status are real.
# Then suspend the Kustomization and change the live Deployment. The controller
# no longer corrects this drift until the learner resumes the Kustomization.
kubectl -n flux-system wait gitrepository/scout-production --for=condition=Ready --timeout=180s
kubectl -n flux-system wait kustomization/scout-production --for=condition=Ready --timeout=240s
kubectl -n flux-system patch kustomization scout-production --type=merge -p '{"spec":{"suspend":true}}'
kubectl -n starfleet-production set env deployment/scout PODINFO_UI_MESSAGE=production-manual-change
kubectl -n starfleet-production rollout status deployment/scout --timeout=180s
