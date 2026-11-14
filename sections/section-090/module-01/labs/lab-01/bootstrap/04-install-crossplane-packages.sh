#!/usr/bin/env bash
# Plumbing: install the provider and the function that the platform needs, and
# give the provider its permissions, so the task starts at the GitOps delivery.
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-kubernetes
spec:
  serviceAccountTemplate:
    metadata:
      name: provider-kubernetes
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:v1.4.1
  runtimeConfigRef:
    name: provider-kubernetes
---
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.11.2
YAML

kubectl wait providers.pkg.crossplane.io/provider-kubernetes --for=condition=Healthy --timeout=300s
kubectl wait functions.pkg.crossplane.io/function-patch-and-transform --for=condition=Healthy --timeout=300s

kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: provider-kubernetes-workloads
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-kubernetes-workloads
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: provider-kubernetes-workloads
subjects:
  - kind: ServiceAccount
    name: provider-kubernetes
    namespace: crossplane-system
YAML

# The ClusterProviderConfig kind exists only after the provider is Healthy.
for _ in $(seq 1 30); do
  kubectl get crd clusterproviderconfigs.kubernetes.m.crossplane.io >/dev/null 2>&1 && break
  sleep 2
done
kubectl apply -f - <<'YAML'
apiVersion: kubernetes.m.crossplane.io/v1alpha1
kind: ClusterProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
YAML
