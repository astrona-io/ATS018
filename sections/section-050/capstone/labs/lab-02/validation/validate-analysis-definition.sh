#!/usr/bin/env bash
# Grades the background analysis: which hash the Rollout passes and what the AnalysisTemplate measures.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }
ro() { kubectl -n "$NS" get rollout scout -o jsonpath="$1" 2>/dev/null; }

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
[[ "$query" == *'status=~"2.."'* && "$query" != *'status=~"5..'* ]] || fail "the query must count status 2xx responses as the success share"

echo "PASS: the analysis measures the 2xx share of the latest template"
