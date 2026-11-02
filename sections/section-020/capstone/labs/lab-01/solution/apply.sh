#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

AUTH="platform:starfleet-gitops"
LOCAL_PORT=$(( 30000 + RANDOM % 20000 ))
kubectl -n gitea port-forward svc/gitea-http "$LOCAL_PORT:3000" >/dev/null 2>&1 &
PF=$!
WORK="$(mktemp -d)"
trap 'kill $PF 2>/dev/null || true; rm -rf "$WORK"' EXIT
for i in $(seq 1 30); do curl -fs "http://127.0.0.1:$LOCAL_PORT/api/v1/version" >/dev/null 2>&1 && break; sleep 1; done

# Fix the image tag in Git, then turn on automated sync for probe.
git clone -q "http://$AUTH@127.0.0.1:$LOCAL_PORT/starfleet/platform-apps.git" "$WORK/platform-apps"
sed -i.bak 's#go-httpbin:2.25.9#go-httpbin:2.25.0#' "$WORK/platform-apps/apps/probe/deployment.yaml"
rm -f "$WORK/platform-apps/apps/probe/deployment.yaml.bak"
git -C "$WORK/platform-apps" -c user.name=platform -c user.email=platform@starfleet.local commit -q -am "Fix the probe image tag"
git -C "$WORK/platform-apps" push -q origin main
kubectl -n argocd patch application probe --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl -n argocd annotate application probe argocd.argoproj.io/refresh=hard --overwrite >/dev/null

cat > "$WORK/appproject-outpost.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: outpost
  namespace: argocd
spec:
  description: Applications of the outpost team
  sourceRepos:
    - http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git
  destinations:
    - server: https://kubernetes.default.svc
      namespace: outpost
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: ''
      kind: Service
YAML
cat > "$WORK/applicationset-scout-envs.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: scout-envs
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - list:
        elements:
          - env: staging
          - env: production
  template:
    metadata:
      name: 'scout-{{.env}}'
    spec:
      project: default
      source:
        repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
        targetRevision: main
        path: 'envs/{{.env}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'starfleet-{{.env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
YAML
cat > "$WORK/application-outpost-scout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: outpost-scout
  namespace: argocd
spec:
  project: outpost
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git
    targetRevision: main
    path: scout
  destination:
    server: https://kubernetes.default.svc
    namespace: outpost
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

kubectl apply -f "$WORK/appproject-outpost.yaml"
kubectl apply -f "$WORK/applicationset-scout-envs.yaml"
kubectl apply -f "$WORK/application-outpost-scout.yaml"
for app in probe scout-staging scout-production outpost-scout; do
  kubectl -n argocd wait --for=create application/$app --timeout=120s
  kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/$app --timeout=180s
  kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/$app --timeout=180s
done
