#!/usr/bin/env bash
# Grades the outpost team's Application, and proves the project rejects another repository.
set -u

fail() { echo "FAIL: $*"; exit 1; }
cleanup() { kubectl -n argocd delete application outpost-probe-check --ignore-not-found >/dev/null 2>&1; }
trap cleanup EXIT

kubectl -n argocd get application outpost-scout >/dev/null 2>&1 || fail "no Application outpost-scout in the namespace argocd"
get() { kubectl -n argocd get application outpost-scout -o jsonpath="$1"; }

[[ "$(get '{.spec.project}')" == "outpost" ]] || fail "outpost-scout uses project '$(get '{.spec.project}')', expected outpost"
[[ "$(get '{.spec.source.repoURL}')" == "http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git" ]] || fail "outpost-scout has the wrong repoURL"
[[ "$(get '{.spec.destination.namespace}')" == "outpost" ]] || fail "outpost-scout deploys to '$(get '{.spec.destination.namespace}')', expected outpost"
[[ "$(get '{.spec.syncPolicy.automated.selfHeal}')" == "true" ]] || fail "outpost-scout does not have automated sync with selfHeal"
[[ "$(get '{.status.sync.status}')" == "Synced" ]] || fail "outpost-scout sync status is '$(get '{.status.sync.status}')', expected Synced"
[[ "$(get '{.status.health.status}')" == "Healthy" ]] || fail "outpost-scout health status is '$(get '{.status.health.status}')', expected Healthy"

body=""
for i in $(seq 1 10); do
  body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 5 "http://scout.outpost/" 2>/dev/null)
  grep -q '"version"' <<<"$body" && break
  sleep 3
done
grep -q '"version"' <<<"$body" || fail "request from shuttle to scout.outpost returned no version (got: ${body:-nothing})"

# Behaviour of the project: an Application in project outpost must not be able to use platform-apps.
kubectl apply -f - >/dev/null <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: outpost-probe-check
  namespace: argocd
spec:
  project: outpost
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
    targetRevision: main
    path: apps/probe
  destination:
    server: https://kubernetes.default.svc
    namespace: outpost
YAML
found=""
for i in $(seq 1 20); do
  msg=$(kubectl -n argocd get application outpost-probe-check -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)
  if grep -q 'not permitted in project' <<<"$msg"; then found=yes; break; fi
  sleep 3
done
[[ -n "$found" ]] || fail "an Application in project outpost could use platform-apps - the project does not restrict sourceRepos"

echo "PASS: outpost-scout runs in the outpost project and the project rejects another repository"
