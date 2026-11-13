#!/usr/bin/env bash
# Install gate-recorder: a small watcher that writes the blue/green gate history of the Rollout scout
# into the ConfigMap gate-trace (namespace starfleet). For each pod template hash H it records:
#   H.paused    the Rollout reached the BlueGreenPause for H
#   H.analysis  the PrePromotion AnalysisRun for H ended Successful
#   H.switch    ok  = the active selector switched to H after both of the above
#               bad = the active selector switched to H before the pause or before the analysis passed
# Kubernetes Events expire after about an hour; this record does not, so the grader can tell
# a gated promotion from `promote --full` at any time.
set -euo pipefail

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gate-recorder
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gate-recorder
  namespace: starfleet
rules:
  - apiGroups: ["argoproj.io"]
    resources: ["rollouts", "analysisruns"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["gate-trace"]
    verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gate-recorder
  namespace: starfleet
subjects:
  - kind: ServiceAccount
    name: gate-recorder
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: gate-recorder
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gate-trace
  namespace: starfleet
data: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gate-recorder
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gate-recorder
  template:
    metadata:
      labels:
        app: gate-recorder
    spec:
      serviceAccountName: gate-recorder
      containers:
        - name: recorder
          image: curlimages/curl:8.22.0
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh", "-c"]
          args:
            - |
              SA=/var/run/secrets/kubernetes.io/serviceaccount
              API=https://kubernetes.default.svc
              AUTH="Authorization: Bearer $(cat $SA/token)"
              CM="$API/api/v1/namespaces/starfleet/configmaps/gate-trace"
              record() {
                curl -s -o /dev/null --cacert $SA/ca.crt -H "$AUTH" -X PATCH \
                  -H "Content-Type: application/merge-patch+json" \
                  -d "{\"data\":{\"$1\":\"$2\"}}" "$CM"
              }
              watch_kind() {
                curl -sN --cacert $SA/ca.crt -H "$AUTH" \
                  "$API/apis/argoproj.io/v1alpha1/namespaces/starfleet/$1watch=1&timeoutSeconds=120"
              }
              watch_rollout() {
                while true; do
                  watch_kind "rollouts?fieldSelector=metadata.name%3Dscout&" | while read -r event; do
                    hash=$(echo "$event" | grep -o '"currentPodHash":"[a-z0-9]*"' | head -n 1 | cut -d'"' -f4)
                    [ -n "$hash" ] || continue
                    if echo "$event" | grep -q '"reason":"BlueGreenPause"'; then
                      record "$hash.paused" seen
                    fi
                    active=$(echo "$event" | grep -o '"activeSelector":"[a-z0-9]*"' | head -n 1 | cut -d'"' -f4)
                    if [ "$active" = "$hash" ]; then
                      trace=$(curl -s -H "Accept: application/json" --cacert $SA/ca.crt -H "$AUTH" "$CM")
                      # Write the switch verdict once, at the first moment the active selector is the hash.
                      echo "$trace" | grep -q "\"$hash.switch\"" && continue
                      if echo "$trace" | grep -q "\"$hash.paused\": *\"seen\"" && echo "$trace" | grep -q "\"$hash.analysis\": *\"seen\""; then
                        record "$hash.switch" ok
                      else
                        record "$hash.switch" bad
                      fi
                    fi
                  done
                  sleep 1
                done
              }
              watch_analysis() {
                while true; do
                  watch_kind "analysisruns?" | while read -r event; do
                    echo "$event" | grep -q '"rollout-type":"PrePromotion"' || continue
                    echo "$event" | grep -q '"phase":"Successful","runSummary"' || continue
                    hash=$(echo "$event" | grep -o '"rollouts-pod-template-hash":"[a-z0-9]*"' | head -n 1 | cut -d'"' -f4)
                    [ -n "$hash" ] && record "$hash.analysis" seen
                  done
                  sleep 1
                done
              }
              watch_analysis &
              watch_rollout
          resources:
            requests:
              cpu: 5m
              memory: 16Mi
            limits:
              memory: 48Mi
YAML

kubectl -n starfleet rollout status deploy/gate-recorder --timeout=120s
