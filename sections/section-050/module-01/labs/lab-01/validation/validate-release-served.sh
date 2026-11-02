#!/usr/bin/env bash
# Grades the release by behaviour: revision history, Rollout status and a real request from shuttle.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get rollout scout >/dev/null 2>&1 || fail "no Rollout scout in $NS"

image=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$image" == "ghcr.io/stefanprodan/podinfo:6.15.0" ]] || fail "the Rollout image is $image, expected ghcr.io/stefanprodan/podinfo:6.15.0"

revision=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.metadata.annotations.rollout\.argoproj\.io/revision}')
[[ "${revision:-0}" -ge 2 ]] || fail "the Rollout is on revision '${revision:-0}'; create it on 6.14.0 and release 6.15.0 as a template change"

# `promote --full` skips the remaining steps. The release-recorder (installed by the lab bootstrap)
# writes every currentStepIndex it sees per pod hash into the ConfigMap release-trace, which does not
# expire. A step-by-step release records every index from 0 to the number of steps; --full jumps.
current=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.currentPodHash}')
step_marks=$(kubectl -n "$NS" get rollout scout -o jsonpath='{range .spec.strategy.canary.steps[*]}x{end}')
step_count=${#step_marks}
kubectl -n "$NS" get configmap release-trace >/dev/null 2>&1 || fail "the ConfigMap release-trace is missing; do not delete it"
for index in $(seq 0 "$step_count"); do
  seen=$(kubectl -n "$NS" get configmap release-trace -o jsonpath="{.data.$current\\.$index}" 2>/dev/null)
  [[ "$seen" == "seen" ]] || fail "the release of $current never reached canary step $index; it was fully promoted with --full - promote each pause step instead"
done

# Extra check while the events still exist.
if kubectl -n "$NS" get events --field-selector involvedObject.kind=Rollout,involvedObject.name=scout,reason=RolloutCompleted \
  -o jsonpath='{.items[*].message}' 2>/dev/null | grep -q 'Full promotion requested'; then
  fail "the release was fully promoted with --full; promote each pause step instead"
fi

phase=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.phase}')
[[ "$phase" == "Healthy" ]] || fail "Rollout phase is '$phase', expected Healthy (promote each pause step)"

stable=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.stableRS}')
[[ -n "$stable" && "$stable" == "$current" ]] || fail "the stable ReplicaSet ($stable) is not the 6.15.0 ReplicaSet ($current)"

available=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.availableReplicas}')
[[ "$available" == "5" ]] || fail "$available available replicas, expected 5"

body=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 10 http://scout/ 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle did not return version 6.15.0"

echo "PASS: the Rollout released 6.15.0 through its canary steps and shuttle receives it"
