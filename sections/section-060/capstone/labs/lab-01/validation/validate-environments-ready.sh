#!/usr/bin/env bash
# Grades by behaviour: Git content, Argo CD status, Crossplane conditions and real requests from shuttle.
set -u

fail() { echo "FAIL: $*"; exit 1; }
RAW="http://gitea-http.gitea.svc:3000/api/v1/repos/starfleet/platform-infra/raw"
git_raw() { kubectl -n starfleet exec deploy/shuttle -- curl -s -u platform:starfleet-gitops "$RAW/$1?ref=main" 2>/dev/null; }

preview=$(git_raw environments/preview/scoutenvironment.yaml)
grep -Eq 'replicas: 1$' <<<"$preview" || fail "Git does not have replicas: 1 (an integer) in environments/preview/scoutenvironment.yaml - fix it in Git"
grep -q 'message: preview' <<<"$preview" || fail "the preview environment in Git must keep message: preview"

composition=$(git_raw platform/composition.yaml)
grep -q 'targetPort: http$' <<<"$composition" || fail "Git does not have targetPort: http in platform/composition.yaml - the Service must use the named container port"

production=$(git_raw environments/production/scoutenvironment.yaml)
grep -q 'replicas: 2' <<<"$production" || fail "production in Git must keep replicas: 2"
grep -q 'message: production' <<<"$production" || fail "production in Git must keep message: production"

[[ "$(kubectl -n argocd get application scout-platform -o jsonpath='{.status.sync.status}' 2>/dev/null)" == "Synced" ]] || fail "the Application is not Synced"
[[ "$(kubectl -n argocd get application scout-platform -o jsonpath='{.status.health.status}' 2>/dev/null)" == "Healthy" ]] || fail "the Application is not Healthy"

for namespace in starfleet-staging starfleet-production starfleet-preview; do
  ready=$(kubectl -n "$namespace" get scoutenvironments.platform.starfleet.dev scout -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [[ "$ready" == "True" ]] || fail "the ScoutEnvironment in $namespace is not Ready"
  body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 "http://scout.$namespace/" 2>/dev/null)
  grep -q '"version": *"6.15.0"' <<<"$body" || fail "the scout service in $namespace did not return version 6.15.0 - Ready does not prove the Service reaches the pods"
  grep -q "\"message\": *\"${namespace#starfleet-}\"" <<<"$body" || fail "the scout service in $namespace did not return the message ${namespace#starfleet-}"
done
[[ "$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.status.availableReplicas}' 2>/dev/null)" == "2" ]] || fail "production does not have 2 available replicas"
[[ "$(kubectl -n starfleet-preview get deploy scout -o jsonpath='{.status.availableReplicas}' 2>/dev/null)" == "1" ]] || fail "preview does not have 1 available replica"

echo "PASS: three environments are Ready from Git, Argo CD is Healthy and shuttle reaches all of them"
