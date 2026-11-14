#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: scout
  namespace: flux-system
spec:
  image: registry.registry.svc:5000/starfleet/scout
  interval: 1m
  insecure: true
---
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: scout
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: scout
  policy:
    semver:
      range: ">=6.14.0"
YAML

# Add the setter marker in Git, as the learner does with git clone/commit/push.
PORT=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$PORT:3000" >/dev/null 2>&1 &
PF=$!
WORK="$(mktemp -d)"
trap 'kill $PF 2>/dev/null || true; rm -rf "$WORK"' EXIT
for i in $(seq 1 30); do curl -fs "http://127.0.0.1:$PORT/api/v1/version" >/dev/null 2>&1 && break; sleep 1; done
git clone -q "http://platform:starfleet-gitops@127.0.0.1:$PORT/starfleet/scout-deploy.git" "$WORK/repo"
cd "$WORK/repo"
sed -i.bak 's|newTag: 6.14.0$|newTag: 6.14.0 # {"$imagepolicy": "flux-system:scout:tag"}|' apps/scout/kustomization.yaml
rm apps/scout/kustomization.yaml.bak
git -c user.name=platform -c user.email=platform@starfleet.local commit -q -am "Add image policy setter"
git push -q origin main

kubectl apply -f - <<'YAML'
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageUpdateAutomation
metadata:
  name: scout
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: scout-deploy
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: fluxcdbot
        email: fluxcdbot@starfleet.local
      messageTemplate: "Update {{ range .Changed.Changes }}{{ .OldValue }} to {{ .NewValue }}{{ end }}"
    push:
      branch: main
  update:
    path: ./apps/scout
    strategy: Setters
YAML

# Wait for the automation to push its commit, then let Flux deliver it.
for i in $(seq 1 90); do
  COMMIT="$(kubectl -n flux-system get imageupdateautomation scout -o jsonpath='{.status.lastPushCommit}' 2>/dev/null || true)"
  [ -n "$COMMIT" ] && break
  sleep 2
done
[ -n "${COMMIT:-}" ] || { echo "image automation did not push a commit" >&2; exit 1; }
kubectl -n flux-system annotate gitrepository/scout-deploy --overwrite "reconcile.fluxcd.io/requestedAt=$(date +%s)"
kubectl -n starfleet wait deploy/scout --for=jsonpath='{.spec.template.spec.containers[0].image}'=registry.registry.svc:5000/starfleet/scout:6.15.0 --timeout=180s
kubectl -n starfleet rollout status deploy/scout --timeout=180s
