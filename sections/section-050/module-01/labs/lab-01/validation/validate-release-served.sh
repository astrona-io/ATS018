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

phase=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.phase}')
[[ "$phase" == "Healthy" ]] || fail "Rollout phase is '$phase', expected Healthy (promote each pause step)"

current=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.currentPodHash}')
stable=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.stableRS}')
[[ -n "$stable" && "$stable" == "$current" ]] || fail "the stable ReplicaSet ($stable) is not the 6.15.0 ReplicaSet ($current)"

available=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.status.availableReplicas}')
[[ "$available" == "5" ]] || fail "$available available replicas, expected 5"

body=$(kubectl -n "$NS" exec deploy/shuttle -- curl -s --max-time 10 http://scout/ 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle did not return version 6.15.0"

echo "PASS: the Rollout released 6.15.0 through its canary steps and shuttle receives it"
