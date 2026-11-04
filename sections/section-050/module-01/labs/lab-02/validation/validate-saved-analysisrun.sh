#!/usr/bin/env bash
# Grades task 5: the saved line matches a Successful AnalysisRun of the current release.
set -u

NS="starfleet"
FILE="/tmp/scout-analysisrun.txt"
fail() { echo "FAIL: $*"; exit 1; }

[[ -s "$FILE" ]] || fail "save the AnalysisRun details to $FILE"

saved=$(<"$FILE")
saved_name=${saved%% *}

kubectl -n "$NS" get analysisrun "$saved_name" >/dev/null 2>&1 || fail "the first word in $FILE is not the name of a live AnalysisRun"

kubectl -n "$NS" get rollout scout >/dev/null 2>&1 || fail "no Rollout scout in $NS"
current=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.currentPodHash}')
run_hash=$(kubectl -n "$NS" get analysisrun "$saved_name" -o jsonpath='{.metadata.labels.rollouts-pod-template-hash}')
[[ "$run_hash" == "$current" ]] || fail "$saved_name does not belong to the current release of scout"

live=$(kubectl -n "$NS" get analysisrun "$saved_name" -o jsonpath='{.metadata.name} {.status.phase} {.status.metricResults[0].measurements[0].value}')
[[ "$live" == *" Successful "* ]] || fail "$saved_name is not Successful; save the AnalysisRun that passed"
[[ "$saved" == "$live" ]] || fail "$FILE does not match the live AnalysisRun; save its name, phase and first measurement value on one line"

echo "PASS: the saved AnalysisRun details match the live AnalysisRun"
