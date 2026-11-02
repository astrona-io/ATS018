#!/usr/bin/env bash
# Grades by behaviour: AnalysisRun history, Rollout status, Service selectors and a real request.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

phases=$(kubectl -n "$NS" get analysisrun -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null)
grep -qx Successful <<<"$phases" || fail "no Successful AnalysisRun - release the good candidate through the gate"
grep -qx Failed <<<"$phases" || fail "no Failed AnalysisRun - the faulty candidate must fail the gate (do not skip the analysis)"

# A genuine pass has measurements of 0.99 or higher; an empty query result is not a pass.
passed_values=$(kubectl -n "$NS" get analysisrun -o jsonpath='{range .items[?(@.status.phase=="Successful")]}{range .status.metricResults[0].measurements[*]}{.value}{"\n"}{end}{end}')
grep -Eq '^\[(0\.99|1)' <<<"$passed_values" || fail "no Successful AnalysisRun has a measurement of 0.99 or higher"

# A genuine failure has measurements below 0.99; an empty result ([]) means the query is wrong, not that the candidate is bad.
failed_values=$(kubectl -n "$NS" get analysisrun -o jsonpath='{range .items[?(@.status.phase=="Failed")]}{range .status.metricResults[0].measurements[*]}{.value}{"\n"}{end}{end}')
grep -q '^\[0\.' <<<"$failed_values" || fail "no Failed AnalysisRun has a measurement below 0.99; a failure from an empty result does not count"

phase=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.phase}')
[[ "$phase" == "Healthy" ]] || fail "Rollout phase is '$phase', expected Healthy"

command=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].command}')
[[ "$command" != *random-error* ]] || fail "the Rollout template still has --random-error"
[[ "$command" == *--port-metrics=9797* ]] || fail "the container command lost --port-metrics=9797"

message=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')
[[ "$message" == "canary-good" ]] || fail "the template message is '$message', expected canary-good"

current=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.currentPodHash}')
stable=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.stableRS}')
[[ "$stable" == "$current" ]] || fail "the stable ReplicaSet is '$stable', expected the current template $current"

ready=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.availableReplicas}')
[[ "$ready" == "4" ]] || fail "availableReplicas is '$ready', expected 4"

# Every response must come from the promoted template.
for _ in 1 2 3 4 5 6 7 8; do
  body=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 10 http://scout.starfleet/ 2>/dev/null)
  grep -q '"message": *"canary-good"' <<<"$body" || fail "a request from shuttle did not return the message canary-good"
done

echo "PASS: the gate failed the faulty candidate, passed canary-good, and canary-good serves"
