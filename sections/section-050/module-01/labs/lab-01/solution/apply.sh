#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: run-tests
  namespace: starfleet
spec:
  params:
    - name: version
      type: string
      default: 6.15.0
  workspaces:
    - name: source
  results:
    - name: version
      description: The tested application version
  steps:
    - name: test
      image: alpine:3.23
      workingDir: $(workspaces.source.path)
      env:
        - name: SCOUT_VERSION
          value: $(params.version)
      script: |
        #!/bin/sh
        set -eu
        sh test.sh
        printf '%s' "$SCOUT_VERSION" > "$(results.version.path)"
YAML

RUN=$(kubectl create -o name -f - <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: scout-ci-
  namespace: starfleet
spec:
  pipelineRef:
    name: scout-ci
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 100Mi
YAML
)
kubectl -n starfleet wait "$RUN" --for=condition=Succeeded --timeout=240s
