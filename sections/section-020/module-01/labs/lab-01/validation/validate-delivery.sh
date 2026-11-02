#!/usr/bin/env bash
# Grades behaviour: Argo CD status, the objects Argo CD tracks, a request from shuttle,
# and a manual scale that Argo CD must revert.
set -u

NS="starfleet-staging"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n argocd get application scout-staging >/dev/null 2>&1 || fail "no Application scout-staging"

sync=$(kubectl -n argocd get application scout-staging -o jsonpath='{.status.sync.status}')
[[ "$sync" == "Synced" ]] || fail "sync status is '$sync', expected Synced"
health=$(kubectl -n argocd get application scout-staging -o jsonpath='{.status.health.status}')
[[ "$health" == "Healthy" ]] || fail "health status is '$health', expected Healthy"

tracking=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
[[ "$tracking" == scout-staging:* ]] || fail "Deployment scout is not tracked by the Application scout-staging - Argo CD must create it, not kubectl"

image=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$image" == "ghcr.io/stefanprodan/podinfo:6.15.0" ]] || fail "staging image is $image, expected ghcr.io/stefanprodan/podinfo:6.15.0"

body=""
for i in $(seq 1 10); do
  body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 5 "http://scout.$NS/" 2>/dev/null)
  grep -q '"version"' <<<"$body" && break
  sleep 3
done
grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle did not return version 6.15.0 (got: ${body:-nothing})"
grep -q '"message": *"staging"' <<<"$body" || fail "request from shuttle did not return message staging"

# Self-heal: scale by hand, then expect Argo CD to put the replica count back to 1.
kubectl -n "$NS" scale deploy/scout --replicas=3 >/dev/null || fail "could not scale deploy/scout"
for i in $(seq 1 40); do
  replicas=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.replicas}')
  [[ "$replicas" == "1" ]] && { echo "PASS: scout 6.15.0 served from Git by Argo CD, and a manual scale was reverted"; exit 0; }
  sleep 3
done
fail "a manual scale to 3 was not reverted - self-heal is not working"
