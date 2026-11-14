#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. Keep in step with solution.md.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

wait_for_pause_at_step() {
  local expected="$1/CanaryPauseStep"
  for _ in $(seq 1 90); do
    [[ "$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.currentStepIndex}/{.status.pauseConditions[0].reason}')" == "$expected" ]] && return 0
    sleep 2
  done
  echo "scout did not pause at step $1" >&2
  return 1
}

wait_for_stable_release() {
  for _ in $(seq 1 90); do
    local phase stable current
    phase="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}')"
    stable="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.stableRS}')"
    current="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.currentPodHash}')"
    [[ "$phase" == "Healthy" && -n "$stable" && "$stable" == "$current" ]] && return 0
    sleep 2
  done
  echo "scout did not finish the release" >&2
  return 1
}

# Task 1: one normal promotion, then a full promotion.
wait_for_pause_at_step 1
kubectl argo rollouts promote scout -n starfleet
wait_for_pause_at_step 3
kubectl argo rollouts promote scout -n starfleet --full
wait_for_stable_release

# Tasks 2 and 3: the finished template and the inline analysis step.
kubectl apply -f "$SCRIPT_DIR/analysistemplate-scout-canary-message.yaml"
kubectl -n starfleet patch rollout scout --type=json \
  -p='[{"op":"replace","path":"/spec/strategy/canary/steps/1","value":{"analysis":{"templates":[{"templateName":"scout-canary-message"}]}}}]'

# Task 4: a new pod template starts a release. The analysis step runs by itself.
kubectl -n starfleet patch rollout scout --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/env","value":[{"name":"PODINFO_UI_MESSAGE","value":"canary-ready"}]}]'
wait_for_pause_at_step 3

# Task 5: save the AnalysisRun of this release.
hash="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.currentPodHash}')"
run_name="$(kubectl -n starfleet get analysisrun -l "rollout-type=Step,rollouts-pod-template-hash=$hash" \
  -o jsonpath='{.items[?(@.status.phase=="Successful")].metadata.name}')"
kubectl -n starfleet get analysisrun "$run_name" \
  -o jsonpath='{.metadata.name} {.status.phase} {.status.metricResults[0].measurements[0].value}{"\n"}' \
  > /tmp/scout-analysisrun.txt

# Task 6: a normal promotion clears the last pause.
kubectl argo rollouts promote scout -n starfleet
wait_for_stable_release
# Terminating pods can stay in the Service endpoints for a few seconds after Healthy.
sleep 15
