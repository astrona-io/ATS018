#!/usr/bin/env bash
# Grades by behaviour: AnalysisRun history, Rollout status, Service selectors and a real request.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

phases=$(kubectl -n "$NS" get analysisrun -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null)
grep -qx Successful <<<"$phases" || fail "no Successful AnalysisRun - release the good candidate (gated-good) through the gate"
grep -qx Failed <<<"$phases" || fail "no Failed AnalysisRun - the faulty candidate must fail the gate (do not skip the analysis)"

# The failed run must belong to a run for the faulty template: its measurements are below 0.99.
failed_values=$(kubectl -n "$NS" get analysisrun -o jsonpath='{range .items[?(@.status.phase=="Failed")]}{range .status.metricResults[0].measurements[*]}{.value}{"\n"}{end}{end}')
grep -q '^\[0\.' <<<"$failed_values" || fail "the failed AnalysisRun has no measurement below 0.99"

# The serving template must have passed its own pre-promotion AnalysisRun. AnalysisRun objects stay in
# the cluster, unlike Events. This catches a template promoted with --full before any analysis ran.
# A --full issued while the analysis is still running does not cancel it, so the event check below
# stays as the extra signal for that case.
current=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.currentPodHash}')
gate_phase=$(kubectl -n "$NS" get analysisrun -l "rollout-type=PrePromotion,rollouts-pod-template-hash=$current" \
  -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null)
grep -qx Successful <<<"$gate_phase" || fail "no Successful pre-promotion AnalysisRun for the serving template $current; it was promoted without passing the gate (do not use --full)"

# Durable check. The gate-recorder (installed by the lab bootstrap) writes into the ConfigMap gate-trace,
# which does not expire. For the serving hash it records the BlueGreenPause, the Successful PrePromotion
# AnalysisRun and whether the active selector switched only after both. `promote --full` switches first.
kubectl -n "$NS" get configmap gate-trace >/dev/null 2>&1 || fail "the ConfigMap gate-trace is missing; do not delete it"
trace() { kubectl -n "$NS" get configmap gate-trace -o jsonpath="{.data.$current\\.$1}" 2>/dev/null; }
[[ "$(trace paused)" == "seen" ]] || fail "the release of $current never paused at BlueGreenPause; it was promoted with --full - promote the paused release instead"
[[ "$(trace analysis)" == "seen" ]] || fail "the pre-promotion AnalysisRun for $current was never recorded as Successful"
[[ "$(trace switch)" == "ok" ]] || fail "the active Service switched to $current before the pause and a Successful analysis; it was promoted with --full - promote the paused release instead"

# Extra check while the events still exist.
if kubectl -n "$NS" get events --field-selector involvedObject.kind=Rollout,involvedObject.name=scout,reason=RolloutCompleted \
  -o jsonpath='{.items[*].message}' 2>/dev/null | grep -q 'Full promotion requested'; then
  fail "a release was promoted with --full; promote the paused release with 'kubectl argo rollouts promote' only"
fi

phase=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.phase}')
[[ "$phase" == "Healthy" ]] || fail "Rollout phase is '$phase', expected Healthy"

command=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].command}')
[[ "$command" != *random-error* ]] || fail "the Rollout template still has --random-error"
[[ "$command" == *--port-metrics=9797* ]] || fail "the container command lost --port-metrics=9797"

message=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')
[[ "$message" == "gated-good" ]] || fail "the template message is '$message', expected gated-good"

for service in scout scout-preview; do
  hash=$(kubectl -n "$NS" get service "$service" -o jsonpath='{.spec.selector.rollouts-pod-template-hash}')
  [[ "$hash" == "$current" ]] || fail "Service $service selects '$hash', expected the current template $current"
done

body=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 10 http://scout.starfleet/ 2>/dev/null)
grep -q '"message": *"gated-good"' <<<"$body" || fail "request from shuttle did not return the message gated-good"

echo "PASS: the gate passed gated-good, failed the faulty candidate, and gated-good serves"
