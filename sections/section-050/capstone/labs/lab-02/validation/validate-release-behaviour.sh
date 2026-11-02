#!/usr/bin/env bash
# Grades by behaviour: AnalysisRun history, Rollout status, the HTTPRoute and real requests from shuttle.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

phases=$(kubectl -n "$NS" get analysisrun -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null)
grep -qx Successful <<<"$phases" || fail "no Successful AnalysisRun - release the good canary and let its analysis finish"
grep -qx Failed <<<"$phases" || fail "no Failed AnalysisRun - the faulty canary must fail its analysis (do not skip it)"

failed_values=$(kubectl -n "$NS" get analysisrun -o jsonpath='{range .items[?(@.status.phase=="Failed")]}{range .status.metricResults[0].measurements[*]}{.value}{"\n"}{end}{end}')
grep -q '^\[0\.' <<<"$failed_values" || fail "the failed AnalysisRun has no measurement below 0.99"

phase=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.phase}')
[[ "$phase" == "Healthy" ]] || fail "Rollout phase is '$phase', expected Healthy"

command=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].command}')
[[ "$command" != *random-error* ]] || fail "the Rollout template still has --random-error"
[[ "$command" == *--port-metrics=9797* ]] || fail "the container command lost --port-metrics=9797"
message=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')
[[ "$message" == "good-build" ]] || fail "the template message is '$message', expected good-build"

rules=$(kubectl -n "$NS" get httproute scout-route -o jsonpath='{.spec.rules[*].name}')
[[ -z "$rules" ]] || fail "the HTTPRoute still has the named rule '$rules'; the managed header route must be gone"
weights=$(kubectl -n "$NS" get httproute scout-route -o jsonpath='{range .spec.rules[*]}{range .backendRefs[*]}{.name}={.weight} {end}{end}')
[[ "$weights" == "scout=100 scout-canary=0 " ]] || fail "the route weights are '$weights', expected scout=100 scout-canary=0"

result=$(kubectl -n "$NS" exec deploy/shuttle -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 http://$GATEWAY/; done | sort | uniq -c' 2>/dev/null)
[[ "$(tr -s ' ' <<<"$result" | sed 's/^ //')" == "10 200" ]] || fail "requests to the Gateway did not all return 200: $result"
body=$(kubectl -n "$NS" exec deploy/shuttle -- sh -c 'curl -s --max-time 10 http://$GATEWAY/' 2>/dev/null)
grep -q '"message": *"good-build"' <<<"$body" || fail "request through the Gateway did not return the message good-build"

echo "PASS: the gate passed good-build, failed the faulty canary, and the Gateway serves good-build"
