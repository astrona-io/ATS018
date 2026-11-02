#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Writes the fixed tree and applies both overlays. Keep in step with solution.md.
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/base" "$WORK/overlays/staging" "$WORK/overlays/production"

cat > "$WORK/base/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
spec:
  replicas: 1
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
          image: ghcr.io/stefanprodan/podinfo
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
YAML
cat > "$WORK/base/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: scout
spec:
  selector:
    app: scout
  ports:
    - name: http
      port: 80
      targetPort: http
YAML
cat > "$WORK/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
labels:
  - pairs:
      app.kubernetes.io/part-of: starfleet
images:
  - name: ghcr.io/stefanprodan/podinfo
    newTag: 6.14.0
YAML
cat > "$WORK/overlays/staging/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: starfleet-staging
resources:
  - ../../base
labels:
  - pairs:
      environment: staging
images:
  - name: ghcr.io/stefanprodan/podinfo
    newTag: 6.15.0
configMapGenerator:
  - name: scout-settings
    literals:
      - PODINFO_UI_MESSAGE=staging
patches:
  - path: deployment-env.yaml
YAML
cat > "$WORK/overlays/staging/deployment-env.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
spec:
  template:
    spec:
      containers:
        - name: scout
          envFrom:
            - configMapRef:
                name: scout-settings
YAML
cat > "$WORK/overlays/production/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: starfleet-production
resources:
  - ../../base
labels:
  - pairs:
      environment: production
replicas:
  - name: scout
    count: 3
patches:
  - target:
      kind: Deployment
      name: scout
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: 64Mi
      - op: add
        path: /spec/template/spec/containers/0/resources/limits
        value:
          memory: 128Mi
YAML

kubectl apply -k "$WORK/overlays/staging"
kubectl apply -k "$WORK/overlays/production"
kubectl -n starfleet-staging rollout status deploy/scout --timeout=180s
kubectl -n starfleet-production rollout status deploy/scout --timeout=180s
