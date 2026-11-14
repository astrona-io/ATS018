#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials
  namespace: starfleet
  annotations:
    tekton.dev/git-0: http://gitea-http.gitea.svc:3000
type: kubernetes.io/basic-auth
stringData:
  username: platform
  password: starfleet-gitops
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: scout-ci
  namespace: starfleet
secrets:
  - name: gitea-credentials
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: scout-release
  namespace: starfleet
spec:
  params:
    - name: revision
      type: string
      default: main
  workspaces:
    - name: source
  tasks:
    - name: fetch-source
      taskRef:
        name: fetch-source
      params:
        - name: url
          value: http://gitea-http.gitea.svc:3000/starfleet/scout-app.git
        - name: revision
          value: $(params.revision)
      workspaces:
        - name: source
          workspace: source
    - name: publish-image
      taskRef:
        name: publish-image
      params:
        - name: version
          value: $(tasks.fetch-source.results.version)
    - name: update-deploy
      runAfter:
        - publish-image
      taskRef:
        name: update-deploy
      params:
        - name: version
          value: $(tasks.fetch-source.results.version)
  results:
    - name: deploy-commit
      value: $(tasks.update-deploy.results.commit)
YAML

RUN=$(kubectl create -o name -f - <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: scout-release-
  namespace: starfleet
spec:
  pipelineRef:
    name: scout-release
  taskRunTemplate:
    serviceAccountName: scout-ci
  workspaces:
    - name: source
      emptyDir: {}
YAML
)
kubectl -n starfleet wait "$RUN" --for=condition=Succeeded --timeout=300s

# Argo CD polls Git about every 3 minutes; ask for a refresh and wait for the new version.
kubectl -n argocd annotate application/scout --overwrite argocd.argoproj.io/refresh=hard
kubectl -n starfleet rollout status deploy/scout --timeout=240s
for i in $(seq 1 60); do
  if kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet | grep -q '"version": "6.15.0"'; then exit 0; fi
  sleep 3
done
echo "scout did not serve 6.15.0" >&2
exit 1
