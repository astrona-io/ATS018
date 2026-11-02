#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

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
for app in scout-staging scout-production outpost-scout; do
  kubectl -n argocd wait --for=create application/$app --timeout=120s
  kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/$app --timeout=180s
  kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/$app --timeout=180s
done
