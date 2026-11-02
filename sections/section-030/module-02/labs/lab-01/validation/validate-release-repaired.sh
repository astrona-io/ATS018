#!/usr/bin/env bash
# Grades the release by behaviour: the same HelmRelease object, its status, the pods and a real request.
set -u

NS=starfleet
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n $NS get helmrelease scout >/dev/null 2>&1 || fail "HelmRelease scout does not exist in $NS"

baseline=$(kubectl -n $NS get configmap lab-baseline -o jsonpath='{.data.helmrelease-uid}' 2>/dev/null)
current=$(kubectl -n $NS get helmrelease scout -o jsonpath='{.metadata.uid}')
[[ -n "$baseline" && "$baseline" == "$current" ]] || fail "HelmRelease scout was deleted and created again - repair the existing release"

[[ "$(kubectl -n $NS get helmrelease scout -o jsonpath='{.spec.suspend}')" != "true" ]] || fail "HelmRelease scout is suspended"

unready=$(kubectl -n $NS get helmrelease scout -o jsonpath='{.spec.values.faults.unready}')
[[ "$unready" != "true" ]] || fail "the values still set faults.unready: true"

ready=$(kubectl -n $NS get helmrelease scout -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
reason=$(kubectl -n $NS get helmrelease scout -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}')
[[ "$ready" == "True" ]] || fail "HelmRelease scout is not Ready (reason: $reason)"

# The newest release revision must be the deployed one and the chart pods must be ready.
latest=$(kubectl -n $NS get helmrelease scout -o jsonpath='{.status.history[0].status}')
[[ "$latest" == "deployed" ]] || fail "newest release revision has status '$latest', expected deployed"

pods_ready=$(kubectl -n $NS get deploy scout-podinfo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ "$pods_ready" == "1" ]] || fail "Deployment scout-podinfo has '$pods_ready' ready replicas, expected 1"

body=$(kubectl -n $NS exec deploy/shuttle -- curl -s --max-time 10 http://scout-podinfo:9898/ 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle did not return version 6.15.0"

echo "PASS: release scout is Ready, revision deployed, shuttle receives version 6.15.0"
