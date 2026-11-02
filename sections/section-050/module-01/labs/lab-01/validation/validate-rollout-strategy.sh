#!/usr/bin/env bash
# Grades the Rollout definition: canary steps, indefinite pause, Deployment removed.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get rollout scout >/dev/null 2>&1 || fail "no Rollout scout in $NS"
if kubectl -n "$NS" get deployment scout >/dev/null 2>&1; then
  fail "the Deployment scout still exists - the Rollout must replace it"
fi

replicas=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.replicas}')
[[ "$replicas" == "5" ]] || fail "Rollout runs $replicas replicas, expected 5"

selector=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.selector.matchLabels.app}')
[[ "$selector" == "scout" ]] || fail "selector app is '$selector', expected scout"

kubectl -n "$NS" get service scout >/dev/null 2>&1 || fail "the Service scout was deleted"

[[ -n "$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary}')" ]] || fail "the Rollout does not use the canary strategy"

first=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[0].setWeight}')
[[ "$first" == "20" ]] || fail "first step is setWeight '$first', expected 20"

pause_step=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[1]}')
[[ "$pause_step" == *pause* ]] || fail "the step after setWeight 20 is not a pause"
duration=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[1].pause.duration}')
[[ -z "$duration" ]] || fail "the first pause has the duration '$duration'; it must wait for a person (no duration)"

mu=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.maxUnavailable}')
[[ "$mu" == "0" ]] || fail "maxUnavailable is '$mu', expected 0"

echo "PASS: scout is a canary Rollout with a 20 percent step and an indefinite pause"
