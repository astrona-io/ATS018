#!/usr/bin/env bash
# Grades the image automation objects by their own status.
set -u

NS=flux-system
fail() { echo "FAIL: $*"; exit 1; }
get() { kubectl -n $NS get "$@" 2>/dev/null; }
ready() { [[ "$(get "$1" "$2" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == "True" ]]; }

get imagerepository scout >/dev/null || fail "no ImageRepository scout in $NS"
[[ "$(get imagerepository scout -o jsonpath='{.spec.image}')" == "registry.registry.svc:5000/starfleet/scout" ]] \
  || fail "ImageRepository scout does not scan registry.registry.svc:5000/starfleet/scout"
ready imagerepository scout || fail "ImageRepository scout is not Ready - read its message with kubectl describe"

get imagepolicy scout >/dev/null || fail "no ImagePolicy scout in $NS"
[[ "$(get imagepolicy scout -o jsonpath='{.spec.imageRepositoryRef.name}')" == "scout" ]] \
  || fail "ImagePolicy scout does not read the ImageRepository scout"
ready imagepolicy scout || fail "ImagePolicy scout is not Ready - its range may match no tag"
tag=$(get imagepolicy scout -o jsonpath='{.status.latestRef.tag}')
[[ "$tag" == "6.15.0" ]] || fail "ImagePolicy scout selected '$tag', expected 6.15.0"

get imageupdateautomation scout >/dev/null || fail "no ImageUpdateAutomation scout in $NS"
[[ "$(get imageupdateautomation scout -o jsonpath='{.spec.update.strategy}')" == "Setters" ]] \
  || fail "ImageUpdateAutomation scout must use strategy Setters"
[[ "$(get imageupdateautomation scout -o jsonpath='{.spec.suspend}')" != "true" ]] || fail "ImageUpdateAutomation scout is suspended"
ready imageupdateautomation scout || fail "ImageUpdateAutomation scout is not Ready"
push=$(get imageupdateautomation scout -o jsonpath='{.status.lastPushCommit}')
[[ -n "$push" ]] || fail "ImageUpdateAutomation scout has not pushed a commit yet (status.lastPushCommit is empty)"

echo "PASS: ImageRepository, ImagePolicy and ImageUpdateAutomation are Ready; the policy selects 6.15.0 and the automation pushed $push"
