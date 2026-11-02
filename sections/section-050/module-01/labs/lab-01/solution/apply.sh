#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Converts the Deployment into a canary Rollout and releases 6.15.0. Keep in step with solution.md.
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/rollout-scout.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: scout
  namespace: starfleet
spec:
  replicas: 5
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:6.14.0
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              memory: 64Mi
  strategy:
    canary:
      maxSurge: 1
      maxUnavailable: 0
      steps:
        - setWeight: 20
        - pause: {}
        - setWeight: 60
        - pause: {}
YAML

kubectl apply -f "$WORK/rollout-scout.yaml"
kubectl argo rollouts status scout -n starfleet --timeout 180s
kubectl -n starfleet delete deployment scout

kubectl argo rollouts set image scout scout=ghcr.io/stefanprodan/podinfo:6.15.0 -n starfleet
for step in 1 2; do
  for _ in $(seq 1 90); do
    paused=$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.pauseConditions[0].reason}' 2>/dev/null || true)
    [[ -n "$paused" ]] && break
    sleep 2
  done
  kubectl argo rollouts promote scout -n starfleet
done
kubectl argo rollouts status scout -n starfleet --timeout 180s
sleep 15
