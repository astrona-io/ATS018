#!/usr/bin/env bash
# Grades task 1: the 6.15.0 release that started paused reached step 3, then a full promotion finished it.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get rollout scout >/dev/null 2>&1 || fail "no Rollout scout in $NS"
kubectl -n "$NS" get configmap release-trace >/dev/null 2>&1 || fail "the ConfigMap release-trace is missing; do not delete it"

first=$(kubectl -n "$NS" get configmap release-trace -o jsonpath='{.data.firstReleaseHash}')
[[ -n "$first" ]] || fail "the ConfigMap release-trace has lost its data; do not change it"

second_pause=$(kubectl -n "$NS" get configmap release-trace -o jsonpath="{.data.$first\\.3}")
[[ "$second_pause" == "seen" ]] || fail "the paused release never reached the second pause; promote once without --full first"

full_mark=$(kubectl -n "$NS" get configmap release-trace -o jsonpath="{.data.$first\\.full}")
if [[ "$full_mark" != "seen" ]]; then
  kubectl -n "$NS" get events --field-selector involvedObject.kind=Rollout,involvedObject.name=scout,reason=RolloutCompleted \
    -o jsonpath='{.items[*].message}' 2>/dev/null | grep -q "($first): Full promotion requested" \
    || fail "the paused release was not finished with a full promotion"
fi

stable=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.stableRS}')
stable_image=$(kubectl -n "$NS" get replicaset "scout-$stable" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[[ "$stable_image" == "ghcr.io/stefanprodan/podinfo:6.15.0" ]] || fail "the stable version is not 6.15.0 yet; wait for the full promotion to finish"

echo "PASS: the paused release stopped at the second pause and a full promotion finished it"
