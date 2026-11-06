#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Creates the Canary, promotes 6.15.0, rolls back a faulty release and promotes the fix.
# Keep in step with solution.md.
set -euo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/canary-scout.yaml" <<'YAML'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: scout
  namespace: starfleet
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  progressDeadlineSeconds: 120
  service:
    port: 80
    targetPort: http
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
    webhooks:
      - name: load-test
        type: rollout
        url: http://flagger-loadtester.starfleet/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 http://scout-canary.starfleet/"
YAML

canary_phase() { kubectl -n starfleet get canary scout -o jsonpath='{.status.phase}' 2>/dev/null || true; }
wait_for_phase() {
  for _ in $(seq 1 120); do
    [[ "$(canary_phase)" == "$1" ]] && return 0
    sleep 5
  done
  echo "Canary did not reach $1" >&2
  kubectl -n starfleet describe canary scout >&2 || true
  return 1
}

kubectl apply -f "$WORK/canary-scout.yaml"
wait_for_phase Initialized
# Give Prometheus time to scrape the first Istio metrics, so the first analysis steps find data.
sleep 60

# After each template change wait until Flagger has started the release (Progressing),
# otherwise the phase of the previous release is read as the result of this one.
kubectl -n starfleet set image deploy/scout scout=ghcr.io/stefanprodan/podinfo:6.15.0
wait_for_phase Progressing
wait_for_phase Succeeded

kubectl -n starfleet patch deploy scout --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["./podinfo","--port=9898","--random-error"]}]'
wait_for_phase Progressing
wait_for_phase Failed

kubectl -n starfleet patch deploy scout --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/command"},{"op":"add","path":"/spec/template/spec/containers/0/env","value":[{"name":"PODINFO_UI_MESSAGE","value":"fixed"}]}]'
wait_for_phase Progressing
wait_for_phase Succeeded
sleep 10
