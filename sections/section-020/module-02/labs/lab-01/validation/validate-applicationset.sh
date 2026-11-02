#!/usr/bin/env bash
# Grades the ApplicationSet by what it generated and what runs in the cluster.
set -u

fail() { echo "FAIL: $*"; exit 1; }

kubectl -n argocd get applicationset scout-envs >/dev/null 2>&1 || fail "no ApplicationSet scout-envs in the namespace argocd"

expect_replicas() { case "$1" in staging) echo 1 ;; production) echo 2 ;; esac; }

for env in staging production; do
  app="scout-$env"
  kubectl -n argocd get application "$app" >/dev/null 2>&1 || fail "no Application $app - the ApplicationSet should generate it"

  owner=$(kubectl -n argocd get application "$app" -o jsonpath='{.metadata.ownerReferences[0].name}')
  [[ "$owner" == "scout-envs" ]] || fail "Application $app is owned by '$owner', expected the ApplicationSet scout-envs (do not create it by hand)"

  path=$(kubectl -n argocd get application "$app" -o jsonpath='{.spec.source.path}')
  [[ "$path" == "envs/$env" ]] || fail "$app syncs path '$path', expected envs/$env"
  ns=$(kubectl -n argocd get application "$app" -o jsonpath='{.spec.destination.namespace}')
  [[ "$ns" == "starfleet-$env" ]] || fail "$app deploys to '$ns', expected starfleet-$env"

  sync=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}')
  health=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.health.status}')
  [[ "$sync" == "Synced" && "$health" == "Healthy" ]] || fail "$app is $sync/$health, expected Synced/Healthy"

  replicas=$(kubectl -n "starfleet-$env" get deploy scout -o jsonpath='{.spec.replicas}')
  [[ "$replicas" == "$(expect_replicas $env)" ]] || fail "starfleet-$env runs $replicas replicas, expected $(expect_replicas $env)"
  label=$(kubectl -n "starfleet-$env" get deploy scout -o jsonpath='{.metadata.labels.environment}')
  [[ "$label" == "$env" ]] || fail "Deployment label environment is '$label', expected $env"

  body=""
  for i in $(seq 1 10); do
    body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 5 "http://scout.starfleet-$env/" 2>/dev/null)
    grep -q '"version"' <<<"$body" && break
    sleep 3
  done
  grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle to scout.starfleet-$env did not return version 6.15.0 (got: ${body:-nothing})"
done

echo "PASS: scout-envs generated scout-staging and scout-production, both Synced, Healthy and answering"
