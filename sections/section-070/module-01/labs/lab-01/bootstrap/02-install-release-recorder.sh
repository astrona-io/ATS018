#!/usr/bin/env bash
# Install release-recorder: a small watcher that writes every canary step index it sees
# for each Rollout pod hash into the ConfigMap release-trace (namespace starfleet).
# Kubernetes Events expire after about an hour; this record does not, so the grader can
# tell a step-by-step promotion from `promote --full` at any time.
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
  name: release-recorder
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: release-recorder
  namespace: starfleet
rules:
  - apiGroups: ["argoproj.io"]
    resources: ["rollouts"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["release-trace"]
    verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: release-recorder
  namespace: starfleet
subjects:
  - kind: ServiceAccount
    name: release-recorder
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: release-recorder
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: release-trace
  namespace: starfleet
data: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: release-recorder
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: release-recorder
  template:
    metadata:
      labels:
        app: release-recorder
    spec:
      serviceAccountName: release-recorder
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
              while true; do
                curl -sN --cacert $SA/ca.crt -H "$AUTH" \
                  "$API/apis/argoproj.io/v1alpha1/namespaces/starfleet/rollouts?watch=1&fieldSelector=metadata.name%3Dscout&timeoutSeconds=120" |
                while read -r event; do
                  hash=$(echo "$event" | grep -o '"currentPodHash":"[a-z0-9]*"' | head -n 1 | cut -d'"' -f4)
                  index=$(echo "$event" | grep -o '"currentStepIndex":[0-9]*' | head -n 1 | cut -d: -f2)
                  [ -n "$hash" ] && [ -n "$index" ] || continue
                  curl -s -o /dev/null --cacert $SA/ca.crt -H "$AUTH" -X PATCH \
                    -H "Content-Type: application/merge-patch+json" \
                    -d "{\"data\":{\"$hash.$index\":\"seen\"}}" \
                    "$API/api/v1/namespaces/starfleet/configmaps/release-trace"
                done
                sleep 1
              done
          resources:
            requests:
              cpu: 5m
              memory: 16Mi
            limits:
              memory: 32Mi
YAML

kubectl -n starfleet rollout status deploy/release-recorder --timeout=120s
