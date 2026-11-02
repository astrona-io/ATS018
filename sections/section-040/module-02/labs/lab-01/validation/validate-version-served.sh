#!/usr/bin/env bash
# Argo CD must deliver the commit, with automated sync and self-heal still on.
set -u

fail() { echo "FAIL: $*"; exit 1; }
argo() { kubectl -n argocd get application scout "$@" 2>/dev/null; }

[[ "$(argo -o jsonpath='{.spec.syncPolicy.automated.selfHeal}')" == "true" ]] \
  || fail "Application scout no longer has automated sync with selfHeal: true"
[[ "$(argo -o jsonpath='{.spec.syncPolicy.automated.prune}')" == "true" ]] \
  || fail "Application scout no longer has automated sync with prune: true"

[[ "$(argo -o jsonpath='{.status.sync.status}')" == "Synced" ]] || fail "Application scout is $(argo -o jsonpath='{.status.sync.status}'), expected Synced"
[[ "$(argo -o jsonpath='{.status.health.status}')" == "Healthy" ]] || fail "Application scout is $(argo -o jsonpath='{.status.health.status}'), expected Healthy"

image=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$image" == "registry.registry.svc:5000/starfleet/scout:6.15.0" ]] || fail "Deployment scout uses '$image'"

answer=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 5 http://scout.starfleet 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$answer" || fail "a request from shuttle to scout did not return version 6.15.0"

echo "PASS: Argo CD is Synced and Healthy and scout answers with version 6.15.0"
