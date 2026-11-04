#!/usr/bin/env bash
# Grades tasks 4 and 6: the environment change passed the analysis step, a normal promotion finished it,
# and a real request from shuttle receives it.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get rollout scout >/dev/null 2>&1 || fail "no Rollout scout in $NS"

image=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$image" == "ghcr.io/stefanprodan/podinfo:6.15.0" ]] || fail "the Rollout image is $image, expected ghcr.io/stefanprodan/podinfo:6.15.0"

message=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')
[[ "$message" == "canary-ready" ]] || fail "PODINFO_UI_MESSAGE on the Rollout is '$message', not the value the task names"

current=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.currentPodHash}')
first=$(kubectl -n "$NS" get configmap release-trace -o jsonpath='{.data.firstReleaseHash}' 2>/dev/null)
[[ -n "$first" && "$current" != "$first" ]] || fail "no new release since the paused one; change the pod template"

# The AnalysisRun is a snapshot of the template, so it proves what this release really checked.
successful=$(kubectl -n "$NS" get analysisrun -l "rollout-type=Step,step-index=1,rollouts-pod-template-hash=$current" \
  -o jsonpath='{.items[?(@.status.phase=="Successful")].metadata.name}' 2>/dev/null)
[[ -n "$successful" ]] || fail "this release has no Successful AnalysisRun from the analysis step"
run_name=${successful%% *}

run_url=$(kubectl -n "$NS" get analysisrun "$run_name" -o jsonpath='{.spec.metrics[0].provider.web.url}')
[[ "$run_url" == "http://scout-canary.starfleet/" ]] || fail "the AnalysisRun $run_name did not request the canary Service"

# The web provider stores a string measurement as JSON, so the value keeps its double quotes.
run_value=$(kubectl -n "$NS" get analysisrun "$run_name" -o jsonpath='{.status.metricResults[0].measurements[0].value}')
[[ "$run_value" == '"canary-ready"' ]] || fail "the AnalysisRun $run_name measured $run_value, not the expected message"

# A release that was fully promoted never stops at the last pause.
kubectl -n "$NS" get configmap release-trace >/dev/null 2>&1 || fail "the ConfigMap release-trace is missing; do not delete it"
last_pause=$(kubectl -n "$NS" get configmap release-trace -o jsonpath="{.data.$current\\.3}")
[[ "$last_pause" == "seen" ]] || fail "this release never stopped at the last pause"
full_mark=$(kubectl -n "$NS" get configmap release-trace -o jsonpath="{.data.$current\\.full}")
[[ "$full_mark" != "seen" ]] && ! kubectl -n "$NS" get events --field-selector involvedObject.kind=Rollout,involvedObject.name=scout,reason=RolloutCompleted \
  -o jsonpath='{.items[*].message}' 2>/dev/null | grep -q "($current): Full promotion requested" \
  || fail "this release used a full promotion; use a normal promote"

phase=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.phase}')
[[ "$phase" == "Healthy" ]] || fail "Rollout phase is '$phase', expected Healthy"

stable=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.stableRS}')
[[ -n "$stable" && "$stable" == "$current" ]] || fail "the stable ReplicaSet ($stable) is not the new ReplicaSet ($current)"

available=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.availableReplicas}')
[[ "$available" == "5" ]] || fail "$available available replicas, expected 5"

body=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 10 http://scout.starfleet/ 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$body" || fail "the request from shuttle did not return version 6.15.0"
grep -q '"message": *"canary-ready"' <<<"$body" || fail "the request from shuttle did not return the new message; wait for old pods to end"

echo "PASS: the environment change passed the analysis step and shuttle receives it"
