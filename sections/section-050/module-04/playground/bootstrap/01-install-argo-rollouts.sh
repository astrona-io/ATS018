#!/usr/bin/env bash
# Install the Argo Rollouts 1.10.0 controller in the namespace argo-rollouts and
# register the Gateway API traffic router plugin v0.17.0. The controller
# downloads the plugin binary from the plugin's GitHub release when it starts,
# so the ConfigMap and the RBAC rules go in first and the controller restarts.
set -euo pipefail
PLUGIN_VERSION="v0.17.0"
kubectl get namespace argo-rollouts >/dev/null 2>&1 || kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts --server-side --force-conflicts \
  -f https://github.com/argoproj/argo-rollouts/releases/download/v1.10.0/install.yaml >/dev/null
kubectl -n argo-rollouts rollout status deploy/argo-rollouts --timeout=300s

ARCH="$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}')"
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: argo-rollouts-config
  namespace: argo-rollouts
data:
  trafficRouterPlugins: |-
    - name: "argoproj-labs/gatewayAPI"
      location: "https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/${PLUGIN_VERSION}/gatewayapi-plugin-linux-${ARCH}"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argo-rollouts-gateway-api-plugin
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get"]
  - apiGroups: ["gateway.networking.k8s.io"]
    resources: ["httproutes"]
    verbs: ["get", "list", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argo-rollouts-gateway-api-plugin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argo-rollouts-gateway-api-plugin
subjects:
  - kind: ServiceAccount
    name: argo-rollouts
    namespace: argo-rollouts
YAML

kubectl -n argo-rollouts rollout restart deploy/argo-rollouts >/dev/null
kubectl -n argo-rollouts rollout status deploy/argo-rollouts --timeout=300s
for attempt in $(seq 1 60); do
  if kubectl -n argo-rollouts logs deploy/argo-rollouts 2>/dev/null | grep -q "Download complete"; then exit 0; fi
  sleep 5
done
echo "the Gateway API plugin did not download within 300 seconds" >&2
exit 1
