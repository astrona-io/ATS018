#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for attempt in $(seq 1 120); do
  if kubectl -n starfleet-hpa get hpa scout >/dev/null 2>&1; then break; fi
  sleep 2
done
kubectl -n starfleet-hpa get hpa scout -o json > "$DIR/testing/initial-hpa.json"
kubectl -n argocd get application scout-hpa -o json > "$DIR/testing/initial-app.json"
kubectl -n argocd patch application scout-hpa --type=merge -p '{"spec":{"ignoreDifferences":[{"group":"apps","kind":"Deployment","name":"scout","namespace":"starfleet-hpa","jsonPointers":["/spec/replicas"]}],"syncPolicy":{"syncOptions":["CreateNamespace=true","RespectIgnoreDifferences=true"]}}}'
kubectl -n argocd annotate application scout-hpa argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/scout-hpa --timeout=240s
kubectl -n starfleet-hpa wait --for=jsonpath='{.spec.replicas}'=2 deploy/scout --timeout=240s

python3 "$DIR/testing/check-sync.py"
