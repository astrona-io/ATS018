#!/usr/bin/env bash
# Grades the gate definition: the AnalysisTemplate and how the Rollout runs it.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get analysistemplate scout-success >/dev/null 2>&1 || fail "no AnalysisTemplate scout-success in $NS"

address=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].provider.prometheus.address}')
[[ "$address" == *kps-prometheus.monitoring.svc* ]] || fail "the Prometheus address is '$address'; the controller runs in the cluster, use http://kps-prometheus.monitoring.svc:9090"

success=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].successCondition}')
[[ "$success" == *0.99* ]] || fail "successCondition is '$success', expected a check for 0.99 or higher"

limit=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].failureLimit}')
[[ "$limit" == "1" ]] || fail "failureLimit is '${limit:-unset}', expected 1"

query=$(kubectl -n "$NS" get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].provider.prometheus.query}')
[[ "$query" == *rollouts_pod_template_hash* ]] || fail "the query does not select one pod template hash"
[[ "$query" == *path=\"root\"* ]] || fail "the query does not select path=\"root\""

[[ "$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.blueGreen.prePromotionAnalysis.templates[0].templateName}')" == "scout-success" ]] \
  || fail "the Rollout does not run scout-success in prePromotionAnalysis"

latest=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.blueGreen.prePromotionAnalysis.args[0].valueFrom.podTemplateHashValue}')
[[ "$latest" == "Latest" ]] || fail "the analysis argument uses '$latest'; judge the candidate with podTemplateHashValue: Latest"

[[ "$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.blueGreen.autoPromotionEnabled}')" == "false" ]] \
  || fail "autoPromotionEnabled must stay false"

echo "PASS: scout-success queries Prometheus and the Rollout runs it before promotion with the latest hash"
