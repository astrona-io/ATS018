#!/usr/bin/env bash
# Grades the Rollout and the AnalysisTemplate definitions.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }
ro() { kubectl -n "$NS" get rollout scout -o jsonpath="$1" 2>/dev/null; }

kubectl -n "$NS" get rollout scout >/dev/null 2>&1 || fail "no Rollout scout in $NS"

[[ "$(ro '{.spec.strategy.canary.trafficRouting.managedRoutes[*].name}')" == *canary-header* ]] \
  || fail "managedRoutes does not list canary-header"

[[ "$(ro '{.spec.strategy.canary.steps[0].setCanaryScale.replicas}')" == "1" ]] || fail "the first step is not setCanaryScale with replicas 1"
[[ "$(ro '{.spec.strategy.canary.steps[1].setHeaderRoute.name}')" == "canary-header" ]] || fail "the second step is not setHeaderRoute canary-header"
[[ "$(ro '{.spec.strategy.canary.steps[1].setHeaderRoute.match[0].headerName}')" == "x-canary" ]] || fail "the header route does not match the header x-canary"
[[ "$(ro '{.spec.strategy.canary.steps[1].setHeaderRoute.match[0].headerValue.exact}')" == "yes" ]] || fail "the header route does not match the exact value yes"
[[ -n "$(ro '{.spec.strategy.canary.steps[2].pause}')" ]] || fail "the third step is not a pause"
[[ -z "$(ro '{.spec.strategy.canary.steps[2].pause.duration}')" ]] || fail "the pause after the header route must have no duration"
[[ "$(ro '{.spec.strategy.canary.steps[*].setWeight}')" == *20* ]] || fail "no setWeight step"

[[ "$(ro '{.spec.strategy.canary.analysis.templates[0].templateName}')" == "scout-success" ]] || fail "the Rollout does not run scout-success as a background analysis"
start=$(ro '{.spec.strategy.canary.analysis.startingStep}')
[[ "${start:-0}" -ge 4 ]] || fail "startingStep is '${start:-0}'; start the analysis after the first weight step has been set"
[[ "$(ro '{.spec.strategy.canary.analysis.args[0].valueFrom.podTemplateHashValue}')" == "Latest" ]] \
  || fail "the analysis argument must use podTemplateHashValue: Latest"

kubectl -n "$NS" get analysistemplate scout-success >/dev/null 2>&1 || fail "no AnalysisTemplate scout-success in $NS"
address=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].provider.prometheus.address}')
[[ "$address" == *kps-prometheus.monitoring.svc* ]] || fail "the Prometheus address is '$address', expected the in-cluster address"
[[ "$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].successCondition}')" == *0.99* ]] || fail "successCondition does not check 0.99"
[[ "$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].failureLimit}')" == "1" ]] || fail "failureLimit is not 1"
query=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].provider.prometheus.query}')
[[ "$query" == *rollouts_pod_template_hash* && "$query" == *path=\"root\"* ]] || fail "the query must select one template hash and path=\"root\""

echo "PASS: the Rollout has the header route, the steps and the background analysis"
