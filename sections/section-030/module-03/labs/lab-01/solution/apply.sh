#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
# Fixes the two Git faults in the repository and the wrong path in the Application.
set -euo pipefail

AUTH="platform:starfleet-gitops"
LOCAL_PORT=$(( 30000 + RANDOM % 20000 ))
kubectl -n gitea port-forward svc/gitea-http "$LOCAL_PORT:3000" >/dev/null 2>&1 &
PF=$!
WORK="$(mktemp -d)"
trap 'kill $PF 2>/dev/null || true; rm -rf "$WORK"' EXIT
for i in $(seq 1 30); do curl -fs "http://127.0.0.1:$LOCAL_PORT/api/v1/version" >/dev/null 2>&1 && break; sleep 1; done

git clone -q "http://$AUTH@127.0.0.1:$LOCAL_PORT/starfleet/scout-faults.git" "$WORK/scout-faults"
cd "$WORK/scout-faults"
sed -i.bak 's/containerPort: 99999/containerPort: 9898/' reject/scout.yaml
sed -i.bak 's#podinfo:6.51.0#podinfo:6.15.0#' image/scout.yaml
rm -f reject/*.bak image/*.bak
git -c user.name=platform -c user.email=platform@starfleet.local commit -q -am "Fix the rejected port and the image tag"
git push -q origin main

kubectl -n argocd patch application scout-path --type merge -p '{"spec":{"source":{"path":"path"}}}'
# The failed sync of scout-reject keeps retrying the old commit. Stop it so the new commit is used.
kubectl -n argocd patch application scout-reject --type merge -p '{"status":{"operationState":{"phase":"Terminating"}}}'

for app in scout-path scout-reject scout-image; do
  kubectl -n argocd annotate application "$app" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
done
for app in scout-path scout-reject scout-image; do
  kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/$app --timeout=240s
  kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/$app --timeout=240s
done
