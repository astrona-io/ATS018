#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: run-tests
  namespace: starfleet
spec:
  entrypoint: test
  serviceAccountName: workflow-runner
  arguments:
    parameters:
      - name: revision
        value: main
  templates:
    - name: test
      inputs:
        parameters:
          - name: revision
        artifacts:
          - name: source
            path: /src
            git:
              repo: http://gitea-http.gitea.svc:3000/starfleet/scout-app.git
              revision: "{{inputs.parameters.revision}}"
      container:
        image: alpine:3.23
        workingDir: /src
        command: [sh, test.sh]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-executor
  namespace: starfleet
subjects:
  - kind: ServiceAccount
    name: workflow-runner
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workflow-executor
---
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: push-ci
  namespace: argo-events
spec:
  template:
    serviceAccountName: workflow-submitter
  dependencies:
    - name: push-main
      eventSourceName: push-webhook
      eventName: push
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - refs/heads/main
  triggers:
    - template:
        name: run-tests
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: push-ci-
                namespace: starfleet
              spec:
                workflowTemplateRef:
                  name: run-tests
                arguments:
                  parameters:
                    - name: revision
                      value: main
          parameters:
            - src:
                dependencyName: push-main
                dataKey: body.after
              dest: spec.arguments.parameters.0.value
YAML

# The Sensor pod restarts after the change; wait for it before the push.
for i in $(seq 1 60); do
  n=$(kubectl -n argo-events get pods -l 'eventsource-name=push-webhook' --field-selector=status.phase=Running -o name 2>/dev/null | wc -l)
  m=$(kubectl -n argo-events get pods -l 'sensor-name=push-ci' --field-selector=status.phase=Running -o name 2>/dev/null | wc -l)
  [ "$n" -ge 1 ] && [ "$m" -ge 1 ] && break
  sleep 3
done
kubectl -n argo-events rollout status deploy -l sensor-name=push-ci --timeout=120s
sleep 10

# Push a change to main, as the learner does with git clone/commit/push.
PORT=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$PORT:3000" >/dev/null 2>&1 &
PF=$!
WORK="$(mktemp -d)"
trap 'kill $PF 2>/dev/null || true; rm -rf "$WORK"' EXIT
for i in $(seq 1 30); do curl -fs "http://127.0.0.1:$PORT/api/v1/version" >/dev/null 2>&1 && break; sleep 1; done
git clone -q "http://platform:starfleet-gitops@127.0.0.1:$PORT/starfleet/scout-app.git" "$WORK/repo"
cd "$WORK/repo"
echo 6.15.1 > VERSION
git -c user.name=platform -c user.email=platform@starfleet.local commit -q -am "Bump VERSION to 6.15.1"
git push -q origin main

for i in $(seq 1 60); do
  if kubectl -n starfleet get workflows -o name 2>/dev/null | grep -q push-ci-; then break; fi
  sleep 3
done
NAME=$(kubectl -n starfleet get workflows -o name | grep push-ci- | head -1)
kubectl -n starfleet wait "$NAME" --for=jsonpath='{.status.phase}'=Succeeded --timeout=180s
