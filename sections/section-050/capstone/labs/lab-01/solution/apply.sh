#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Fixes the gate, releases a faulty candidate (aborted), then a good candidate (promoted).
# Keep in step with solution.md.
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
    - name: candidate-hash
  metrics:
    - name: success-rate
      initialDelay: 45s
      interval: 20s
      count: 3
      failureLimit: 1
      successCondition: len(result) == 1 && result[0] >= 0.99
      failureCondition: len(result) != 1 || result[0] < 0.99
      provider:
        prometheus:
          address: http://kps-prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.candidate-hash}}",status=~"2.."}[2m]))
            /
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.candidate-hash}}"}[2m]))
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
  replicas: 4
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
        image: ghcr.io/stefanprodan/podinfo:6.15.0
        command:
        - ./podinfo
        - --port=9898
        - --port-metrics=9797
${error_flag}
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
      maxUnavailable: 0
      analysis:
        startingStep: 1
        templates:
        - templateName: scout-success
        args:
        - name: candidate-hash
          valueFrom:
            podTemplateHashValue: Latest
      steps:
      - setWeight: 25
      - pause: {}
      - setWeight: 50
      - pause:
          duration: 20s
YAML
}

count_successful_runs() {
  kubectl -n starfleet get analysisrun -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | grep -cx Successful || true
}

wait_for_rollout() {
  local want="$1"
  for _ in $(seq 1 120); do
    phase=$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}' 2>/dev/null || true)
    [[ "$phase" == "$want" ]] && return 0
    sleep 5
  done
  echo "Rollout did not reach $want" >&2
  kubectl argo rollouts get rollout scout -n starfleet --no-color >&2 || true
  return 1
}

kubectl apply -f "$WORK/analysistemplate-scout-success.yaml"

# Faulty candidate: the background analysis fails and the controller aborts the release.
write_rollout bad-release "        - --random-error"
kubectl apply -f "$WORK/rollout-scout.yaml"
wait_for_rollout Degraded

# Good candidate: the analysis passes while the Rollout waits at the pause, then the operator promotes.
before=$(count_successful_runs)
write_rollout canary-good ""
kubectl apply -f "$WORK/rollout-scout.yaml"
for _ in $(seq 1 120); do
  [[ "$(count_successful_runs)" -gt "$before" ]] && break
  sleep 5
done
kubectl argo rollouts promote scout -n starfleet
wait_for_rollout Healthy
sleep 30
