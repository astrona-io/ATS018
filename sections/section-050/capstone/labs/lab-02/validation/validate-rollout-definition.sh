#!/usr/bin/env bash
# Grades the Rollout: the managed route and the first steps.
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

echo "PASS: the Rollout lists the managed route canary-header and has the scale and header route steps"
