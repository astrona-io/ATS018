#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Delivers platform-infra with Argo CD, adds the ScoutEnvironment health check and
# fixes the production version in Git. Keep in step with solution.md.
set -euo pipefail

WORK="$(mktemp -d)"
PF_PID=""
trap '[[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT

cat > "$WORK/application-scout-platform.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git
    targetRevision: main
    path: .
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - SkipDryRunOnMissingResource=true
YAML

cat > "$WORK/argocd-cm-health-scoutenvironment.yaml" <<'YAML'
data:
  resource.customizations.health.platform.starfleet.dev_ScoutEnvironment: |
    hs = {}
    hs.status = "Progressing"
    hs.message = "Waiting for the Ready condition"
    if obj.status ~= nil and obj.status.conditions ~= nil then
      for _, condition in ipairs(obj.status.conditions) do
        if condition.type == "Ready" then
          if condition.status == "True" then
            hs.status = "Healthy"
            hs.message = "Ready"
          else
            hs.status = "Degraded"
            hs.message = condition.reason .. ": " .. (condition.message or "")
          end
        end
      end
    end
    return hs
YAML

kubectl apply -f "$WORK/application-scout-platform.yaml"
kubectl -n argocd patch configmap argocd-cm --patch-file "$WORK/argocd-cm-health-scoutenvironment.yaml"

# Wait until Argo CD has synced the repository and reports the Application as Degraded.
for _ in $(seq 1 60); do
  health=$(kubectl -n argocd get application scout-platform -o jsonpath='{.status.health.status}' 2>/dev/null || true)
  [[ "$health" == "Degraded" ]] && break
  sleep 5
done
echo "Application health in Argo CD: $health"

# Read the layers: the XR, then the pods.
kubectl -n starfleet-production get scoutenvironments.platform.starfleet.dev scout \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.reason}: {.message}{"\n"}{end}'
kubectl -n starfleet-production get pods

# Fix the version in Git.
LOCAL_PORT=$(( 30000 + RANDOM % 20000 ))
kubectl -n gitea port-forward svc/gitea-http "$LOCAL_PORT:3000" >/dev/null 2>&1 &
PF_PID=$!
for _ in $(seq 1 30); do curl -fs "http://127.0.0.1:$LOCAL_PORT/api/v1/version" >/dev/null 2>&1 && break; sleep 1; done
git clone -q "http://platform:starfleet-gitops@127.0.0.1:$LOCAL_PORT/starfleet/platform-infra.git" "$WORK/platform-infra-fix"
cd "$WORK/platform-infra-fix"
sed -i.bak 's/version: 6.99.0/version: 6.15.0/' environments/production/scoutenvironment.yaml && rm environments/production/scoutenvironment.yaml.bak
git -c user.name=platform -c user.email=platform@starfleet.local commit -q -am "Use the published podinfo tag in production"
git push -q origin main

# Wait for Argo CD to sync the commit and for the XRs to be Ready.
for _ in $(seq 1 90); do
  app=$(kubectl -n argocd get application scout-platform -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)
  ready=$(kubectl get scoutenvironments.platform.starfleet.dev -A -o jsonpath='{range .items[*]}{range .status.conditions[?(@.type=="Ready")]}{.status}{" "}{end}{end}' 2>/dev/null || true)
  [[ "$app" == "Synced/Healthy" && "$ready" == "True True " ]] && break
  sleep 5
done
echo "Application: $app, XR ready: $ready"
[[ "$app" == "Synced/Healthy" && "$ready" == "True True " ]]
