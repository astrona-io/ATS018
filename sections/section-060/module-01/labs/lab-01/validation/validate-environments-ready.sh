#!/usr/bin/env bash
# Grades by behaviour: Git content, Argo CD status, Crossplane conditions and real requests from shuttle.
set -u

fail() { echo "FAIL: $*"; exit 1; }
RAW="http://gitea-http.gitea.svc:3000/api/v1/repos/starfleet/platform-infra/raw"

git_file=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -u platform:starfleet-gitops "$RAW/environments/production/scoutenvironment.yaml?ref=main" 2>/dev/null)
grep -q 'version: 6.15.0' <<<"$git_file" || fail "Git does not have version 6.15.0 in environments/production/scoutenvironment.yaml - fix it in Git, not in the cluster"
grep -q 'replicas: 2' <<<"$git_file" || fail "production in Git must keep replicas: 2"
grep -q 'message: production' <<<"$git_file" || fail "production in Git must keep message: production"

[[ "$(kubectl -n argocd get application scout-platform -o jsonpath='{.status.sync.status}' 2>/dev/null)" == "Synced" ]] || fail "the Application is not Synced"
[[ "$(kubectl -n argocd get application scout-platform -o jsonpath='{.status.health.status}' 2>/dev/null)" == "Healthy" ]] || fail "the Application is not Healthy"

for namespace in starfleet-staging starfleet-production; do
  ready=$(kubectl -n "$namespace" get scoutenvironments.platform.starfleet.dev scout -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [[ "$ready" == "True" ]] || fail "the ScoutEnvironment in $namespace is not Ready"
  body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 "http://scout.$namespace/" 2>/dev/null)
  grep -q '"version": *"6.15.0"' <<<"$body" || fail "the scout service in $namespace did not return version 6.15.0"
done
[[ "$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.status.availableReplicas}' 2>/dev/null)" == "2" ]] || fail "production does not have 2 available replicas"
body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 http://scout.starfleet-production/ 2>/dev/null)
grep -q '"message": *"production"' <<<"$body" || fail "production did not return the message production"

echo "PASS: both environments are Ready from Git, Argo CD is Healthy and shuttle reaches both"
