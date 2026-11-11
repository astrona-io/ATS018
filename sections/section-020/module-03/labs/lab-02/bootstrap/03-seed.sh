#!/usr/bin/env bash
# Plumbing: push scout-faults into Git, give Argo CD the credentials, and
# create only the HPA drift Application.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/seed-repo.sh" scout-faults "$SCRIPT_DIR/../repos/scout-faults"
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: creds-starfleet-org
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: http://gitea-http.gitea.svc:3000/starfleet
  username: platform
  password: starfleet-gitops
YAML
kubectl apply -f "$SCRIPT_DIR/../manifests/applications.yaml"

for attempt in $(seq 1 120); do
  if kubectl -n starfleet-hpa get hpa scout >/dev/null 2>&1; then break; fi
  sleep 2
done
kubectl -n starfleet-hpa rollout status deploy/scout --timeout=240s
kubectl -n starfleet-hpa get hpa scout -o json > "$SCRIPT_DIR/../initial-hpa.json"
kubectl -n argocd get application scout-hpa -o json > "$SCRIPT_DIR/../initial-app.json"
