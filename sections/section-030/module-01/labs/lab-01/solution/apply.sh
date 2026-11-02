#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: scout
  namespace: flux-system
spec:
  interval: 1m
  url: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
  ref:
    branch: main
  secretRef:
    name: scout-readonly
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 1m
  path: ./platform
  prune: true
  sourceRef:
    kind: GitRepository
    name: scout
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: scout
  namespace: flux-system
spec:
  interval: 1m
  path: ./overlays/staging
  prune: true
  targetNamespace: starfleet-staging
  wait: true
  timeout: 1m
  dependsOn:
    - name: platform
  sourceRef:
    kind: GitRepository
    name: scout
YAML

# Change the staging message in Git, as the learner does with git clone/commit/push.
PORT=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$PORT:3000" >/dev/null 2>&1 &
PF=$!
WORK="$(mktemp -d)"
trap 'kill $PF 2>/dev/null || true; rm -rf "$WORK"' EXIT
for i in $(seq 1 30); do curl -fs "http://127.0.0.1:$PORT/api/v1/version" >/dev/null 2>&1 && break; sleep 1; done
git clone -q "http://platform:starfleet-gitops@127.0.0.1:$PORT/starfleet/scout-deploy.git" "$WORK/repo"
cd "$WORK/repo"
sed -i.bak 's/value: staging$/value: staging-v2/' overlays/staging/message.yaml && rm overlays/staging/message.yaml.bak
git add overlays/staging/message.yaml
git -c user.name=platform -c user.email=platform@starfleet.local commit -q -m "Update staging message"
git push -q origin main

kubectl -n flux-system wait gitrepository/scout --for=condition=Ready --timeout=120s
STAMP="$(date +%s)"
for obj in gitrepository/scout kustomization/platform kustomization/scout; do
  kubectl -n flux-system annotate "$obj" --overwrite "reconcile.fluxcd.io/requestedAt=$STAMP"
done
kubectl -n flux-system wait kustomization/platform kustomization/scout --for=condition=Ready --timeout=180s
