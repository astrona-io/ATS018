#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Adds the header route and the background analysis, releases a good and a faulty canary,
# and restores the good template. Keep in step with solution.md.
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/analysistemplate-scout-success.yaml" <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: scout-success
  namespace: starfleet
spec:
  args:
    - name: canary-hash
  metrics:
    - name: success-rate
      initialDelay: 45s
      interval: 15s
      failureLimit: 1
      successCondition: len(result) == 1 && result[0] >= 0.99
      failureCondition: len(result) != 1 || result[0] < 0.99
      provider:
        prometheus:
          address: http://kps-prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.canary-hash}}",status=~"2.."}[1m]))
            /
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.canary-hash}}"}[1m]))
YAML

write_rollout() {
  local message="$1" error_flag="$2"
  cat > "$WORK/rollout-scout.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: scout
  namespace: starfleet
spec:
  replicas: 2
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
          command: ["./podinfo", "--port=9898", "--port-metrics=9797"${error_flag}]
          env:
            - name: PODINFO_UI_MESSAGE
              value: ${message}
          ports:
            - name: http
              containerPort: 9898
            - name: metrics
              containerPort: 9797
          readinessProbe:
            tcpSocket:
              port: http
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              memory: 64Mi
  strategy:
    canary:
      stableService: scout
      canaryService: scout-canary
      trafficRouting:
        managedRoutes:
          - name: canary-header
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: scout-route
            namespace: starfleet
      analysis:
        templates:
          - templateName: scout-success
        startingStep: 4
        args:
          - name: canary-hash
            valueFrom:
              podTemplateHashValue: Latest
      steps:
        - setCanaryScale:
            replicas: 1
        - setHeaderRoute:
            name: canary-header
            match:
              - headerName: x-canary
                headerValue:
                  exact: "yes"
        - pause: {}
        - setWeight: 20
        - pause: {duration: 90s}
        - setWeight: 50
        - pause: {duration: 30s}
YAML
}

wait_for_header_pause() {
  for _ in $(seq 1 90); do
    step=$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.currentStepIndex}' 2>/dev/null || true)
    paused=$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.pauseConditions[0].reason}' 2>/dev/null || true)
    [[ "$step" == "2" && -n "$paused" ]] && return 0
    sleep 5
  done
  echo "Rollout did not reach the header pause" >&2
  return 1
}
wait_for_phase() {
  for _ in $(seq 1 120); do
    [[ "$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}' 2>/dev/null || true)" == "$1" ]] && return 0
    sleep 5
  done
  echo "Rollout did not reach $1" >&2
  kubectl argo rollouts get rollout scout -n starfleet --no-color >&2 || true
  return 1
}

kubectl apply -f "$WORK/analysistemplate-scout-success.yaml"

# Good canary: header test, promote, analysis passes.
write_rollout good-build ""
kubectl apply -f "$WORK/rollout-scout.yaml"
wait_for_header_pause
GATEWAY_ADDRESS=$(kubectl -n starfleet get deploy shuttle -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GATEWAY")].value}')
kubectl -n starfleet exec deploy/shuttle -- curl -s -H "x-canary: yes" "http://${GATEWAY_ADDRESS}/" | grep '"message"'
kubectl argo rollouts promote scout -n starfleet
wait_for_phase Healthy

# Faulty canary: the background analysis fails and the controller aborts.
write_rollout bad-build ', "--random-error"'
kubectl apply -f "$WORK/rollout-scout.yaml"
wait_for_header_pause
kubectl argo rollouts promote scout -n starfleet
wait_for_phase Degraded

# Restore the accepted template.
write_rollout good-build ""
kubectl apply -f "$WORK/rollout-scout.yaml"
wait_for_phase Healthy
sleep 20
