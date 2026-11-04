#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail
NS="starfleet"
export PATH="$HOME/.astrona/bin:$PATH"
LOG_FILE="/tmp/outpost-rigel-run.log"

# kubectl label needs the patch verb on the namespace.
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-provisioner
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "create", "patch"]
YAML

# Add the tier param and the parallel Task.
kubectl apply -f - <<'YAML'
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: outpost-onboard
  namespace: starfleet
spec:
  params:
    - name: site
      type: string
    - name: tier
      type: string
  tasks:
    - name: plan-namespace
      taskRef:
        name: plan-namespace
      params:
        - name: site
          value: $(params.site)
    - name: create-namespace
      runAfter:
        - plan-namespace
      taskRef:
        name: create-namespace
      params:
        - name: namespace
          value: $(tasks.plan-namespace.results.namespace)
    - name: report-namespace
      runAfter:
        - create-namespace
      taskRef:
        name: report-namespace
      params:
        - name: namespace
          value: $(tasks.plan-namespace.results.namespace)
    - name: label-namespace
      runAfter:
        - create-namespace
      taskRef:
        name: label-namespace
      params:
        - name: namespace
          value: $(tasks.plan-namespace.results.namespace)
        - name: tier
          value: $(params.tier)
YAML

# Start one run for each site, and wait for each one to end.
VEGA_RUN="$(tkn -n "$NS" pipeline start outpost-onboard -p site=vega -p tier=gold -s outpost-provisioner -o name)"
kubectl -n "$NS" wait "pipelinerun/$VEGA_RUN" --for=condition=Succeeded --timeout=300s

RIGEL_RUN="$(tkn -n "$NS" pipeline start outpost-onboard -p site=rigel -p tier=silver -s outpost-provisioner -o name)"
kubectl -n "$NS" wait "pipelinerun/$RIGEL_RUN" --for=condition=Succeeded --timeout=300s

# The run has ended, so its log is complete.
tkn -n "$NS" pipelinerun logs "$RIGEL_RUN" > "$LOG_FILE"

tkn -n "$NS" pipelinerun delete outpost-onboard-first-try -f
tkn -n "$NS" pipelinerun list
