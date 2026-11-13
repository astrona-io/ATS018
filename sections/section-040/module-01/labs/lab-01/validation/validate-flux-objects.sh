#!/usr/bin/env bash
# Grades the Flux objects by their own status, not only by their existence.
set -u

fail() { echo "FAIL: $*"; exit 1; }
flux_get() { kubectl -n flux-system get "$@" 2>/dev/null; }

branch=$(flux_get gitrepository scout -o jsonpath='{.spec.ref.branch}')
[[ "$branch" == "main" ]] || fail "GitRepository scout follows branch '$branch', expected main"
[[ "$(flux_get gitrepository scout -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == "True" ]] \
  || fail "GitRepository scout is not Ready"

flux_get kustomization platform >/dev/null || fail "no Kustomization platform in flux-system"
[[ "$(flux_get kustomization platform -o jsonpath='{.spec.path}')" == "./platform" ]] \
  || fail "Kustomization platform does not apply ./platform"

[[ "$(flux_get kustomization scout -o jsonpath='{.spec.path}')" == "./overlays/staging" ]] \
  || fail "Kustomization scout does not apply ./overlays/staging"
dep=$(flux_get kustomization scout -o jsonpath='{.spec.dependsOn[*].name}')
[[ "$dep" == "platform" ]] || fail "Kustomization scout dependsOn is '$dep', expected platform"
[[ "$(flux_get kustomization scout -o jsonpath='{.spec.prune}')" == "true" ]] || fail "Kustomization scout must keep prune: true"

for name in platform scout; do
  [[ "$(flux_get kustomization "$name" -o jsonpath='{.spec.suspend}')" != "true" ]] || fail "Kustomization $name is suspended"
  [[ "$(flux_get kustomization "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == "True" ]] \
    || fail "Kustomization $name is not Ready"
done

echo "PASS: source follows main, platform applies first, scout depends on it, all Ready"
