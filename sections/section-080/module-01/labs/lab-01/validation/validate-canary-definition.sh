#!/usr/bin/env bash
# Grades the Canary definition.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }
get() { kubectl -n "$NS" get canary scout -o jsonpath="$1" 2>/dev/null; }

kubectl -n "$NS" get canary scout >/dev/null 2>&1 || fail "no Canary scout in $NS"

[[ "$(get '{.spec.provider}')" == "istio" ]] || fail "the provider is '$(get '{.spec.provider}')', expected istio"
[[ "$(get '{.spec.targetRef.kind}/{.spec.targetRef.name}')" == "Deployment/scout" ]] || fail "targetRef is not Deployment/scout"
[[ "$(get '{.spec.service.port}')" == "80" ]] || fail "service port is not 80"
[[ "$(get '{.spec.service.targetPort}')" == "http" ]] || fail "service targetPort is not http"

[[ "$(get '{.spec.analysis.interval}')" == "30s" ]] || fail "analysis interval is '$(get '{.spec.analysis.interval}')', expected 30s"
[[ "$(get '{.spec.analysis.threshold}')" == "5" ]] || fail "threshold is '$(get '{.spec.analysis.threshold}')', expected 5"
[[ "$(get '{.spec.analysis.stepWeight}')" == "10" ]] || fail "stepWeight is '$(get '{.spec.analysis.stepWeight}')', expected 10"
[[ "$(get '{.spec.analysis.maxWeight}')" == "50" ]] || fail "maxWeight is '$(get '{.spec.analysis.maxWeight}')', expected 50"

min=$(get '{.spec.analysis.metrics[?(@.name=="request-success-rate")].thresholdRange.min}')
[[ -n "$min" ]] || fail "no request-success-rate metric with thresholdRange.min"
(( ${min%.*} >= 99 )) || fail "request-success-rate minimum is $min, expected 99"
window=$(get '{.spec.analysis.metrics[?(@.name=="request-success-rate")].interval}')
[[ "$window" == "1m" ]] || fail "request-success-rate interval is '$window', expected 1m"

hook=$(get '{.spec.analysis.webhooks[?(@.type=="rollout")].metadata.cmd}')
[[ "$hook" == *hey* && "$hook" == *scout-canary.starfleet* ]] || fail "no rollout webhook that sends load to scout-canary.starfleet"

echo "PASS: the Canary targets scout with the Istio provider and the 99 percent check"
