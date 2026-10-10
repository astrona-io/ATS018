#!/usr/bin/env bash
# Plumbing: start the in-cluster registry, let the node's containerd pull from
# it over plain HTTP, and copy podinfo 6.14.0 into it as starfleet/scout:6.14.0.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/registry.yaml"
kubectl -n registry rollout status deploy/registry --timeout=300s
REGISTRY_IP="$(kubectl -n registry get svc registry -o jsonpath='{.spec.clusterIP}')"
kubectl apply -f - <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: containerd-registry-host
  namespace: registry
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: write-hosts-toml
          image: alpine:3.23
          securityContext:
            privileged: true
          command:
            - sh
            - -c
            - |
              set -e
              mkdir -p "/certs.d/registry.registry.svc:5000"
              printf 'server = "http://${REGISTRY_IP}:5000"\n\n[host."http://${REGISTRY_IP}:5000"]\n  capabilities = ["pull", "resolve"]\n' \
                > "/certs.d/registry.registry.svc:5000/hosts.toml"
          volumeMounts:
            - { name: certs, mountPath: /certs.d }
      volumes:
        - name: certs
          hostPath:
            path: /etc/containerd/certs.d
            type: DirectoryOrCreate
---
apiVersion: batch/v1
kind: Job
metadata:
  name: seed-scout-image
  namespace: registry
spec:
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: crane
          image: gcr.io/go-containerregistry/crane:v0.22.1
          args: ["copy", "--insecure", "ghcr.io/stefanprodan/podinfo:6.14.0", "registry.registry.svc:5000/starfleet/scout:6.14.0"]
YAML
kubectl -n registry wait --for=condition=complete job/containerd-registry-host --timeout=180s
kubectl -n registry wait --for=condition=complete job/seed-scout-image --timeout=300s
