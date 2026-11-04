#!/usr/bin/env bash
# Reference solution. Keep it in step with solution.md.
set -euo pipefail
NS="starfleet"
export PATH="$HOME/.astrona/bin:$PATH"
unset ARGO_SERVER ARGO_TOKEN
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Fix the file name and run a copy of the step in the same group.
cat > "$WORK_DIR/scout-check.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: scout-check
  namespace: starfleet
spec:
  entrypoint: main
  serviceAccountName: workflow-runner
  arguments:
    parameters:
      - name: expected-version
        value: "6.15.0"
  volumes:
    - name: release
      configMap:
        name: scout-release
  templates:
    - name: main
      steps:
        - - name: prepare
            template: prepare
        - - name: check-version
            template: check-version
          - name: check-version-copy
            template: check-version
    - name: prepare
      container:
        image: alpine:3.23
        command: [echo, preparing the release check]
    - name: check-version
      container:
        image: alpine:3.23
        command: [sh, -c]
        args:
          - grep -Fqx "{{workflow.parameters.expected-version}}" /release/VERSION && echo release check passed
        volumeMounts:
          - name: release
            mountPath: /release
YAML
argo template update "$WORK_DIR/scout-check.yaml"

SCOUT_RUN="$(argo submit -n "$NS" --from workflowtemplate/scout-check -o name)"
kubectl -n "$NS" wait "workflow/$SCOUT_RUN" --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s

OUTPOST_RUN="$(argo submit -n "$NS" --from workflowtemplate/outpost-config -p target-namespace=outpost --serviceaccount outpost-provisioner -o name)"
kubectl -n "$NS" wait "workflow/$OUTPOST_RUN" --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s

# The seeded run is the only other Workflow.
argo delete -n "$NS" -l workflows.argoproj.io/workflow-template=scout-check --status Failed,Error
argo list -n "$NS"
