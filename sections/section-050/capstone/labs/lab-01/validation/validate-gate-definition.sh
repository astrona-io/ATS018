#!/usr/bin/env bash
# Grades the gate definition: the AnalysisTemplate and how the canary Rollout runs it.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get analysistemplate scout-success >/dev/null 2>&1 || fail "no AnalysisTemplate scout-success in $NS"

address=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].provider.prometheus.address}')
[[ "$address" == *kps-prometheus.monitoring.svc* ]] || fail "the Prometheus address is '$address'; use http://kps-prometheus.monitoring.svc:9090"

success=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].successCondition}')
[[ "$success" == *0.99* ]] || fail "successCondition is '$success', expected a check for 0.99 or higher"

limit=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].failureLimit}')
[[ "$limit" == "1" ]] || fail "failureLimit is '${limit:-unset}', expected 1"

query=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].provider.prometheus.query}')
[[ "$query" == *rollouts_pod_template_hash* ]] || fail "the query does not select one pod template hash"
[[ "$query" == *path=\"root\"* ]] || fail "the query does not select path=\"root\" (podinfo labels requests to / with root)"
[[ "$query" == *status=~* ]] || fail "the query does not split the requests by status"

[[ "$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.analysis.templates[0].templateName}')" == "scout-success" ]] \
  || fail "the Rollout does not run scout-success as a background analysis"

arg=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.analysis.args[?(@.name=="candidate-hash")].valueFrom.podTemplateHashValue}')
[[ "$arg" == "Latest" ]] || fail "the argument candidate-hash is '${arg:-missing}'; pass the candidate with valueFrom podTemplateHashValue: Latest"

steps=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[*].pause}')
[[ -n "$steps" ]] || fail "the canary steps have no pause; keep the pause that holds the candidate while the analysis runs"

echo "PASS: scout-success queries path root for the latest hash and the canary Rollout runs it"
