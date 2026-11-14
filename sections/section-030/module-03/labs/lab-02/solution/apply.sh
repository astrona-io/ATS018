#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl -n argocd patch application scout-hpa --type=merge -p '{"spec":{"ignoreDifferences":[{"group":"apps","kind":"Deployment","name":"scout","namespace":"starfleet-hpa","jsonPointers":["/spec/replicas"]}],"syncPolicy":{"syncOptions":["CreateNamespace=true","RespectIgnoreDifferences=true"]}}}'
kubectl -n argocd annotate application scout-hpa argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/scout-hpa --timeout=240s
kubectl -n starfleet-hpa wait --for=jsonpath='{.spec.replicas}'=2 deploy/scout --timeout=240s
