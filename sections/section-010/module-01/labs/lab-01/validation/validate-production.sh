#!/usr/bin/env bash
# Grades production by behaviour: the live Deployment and a real request from shuttle.
set -u

NS="starfleet-production"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get deploy scout >/dev/null 2>&1 || fail "no Deployment scout in $NS - apply the production overlay"

image=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$image" == "ghcr.io/stefanprodan/podinfo:6.14.0" ]] || fail "production image is $image, expected ghcr.io/stefanprodan/podinfo:6.14.0"

replicas=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.replicas}')
[[ "$replicas" == "3" ]] || fail "production runs $replicas replicas, expected 3"

ready=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.status.readyReplicas}')
[[ "$ready" == "3" ]] || fail "production has $ready ready replicas, expected 3"

env_label=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.metadata.labels.environment}')
[[ "$env_label" == "production" ]] || fail "label environment is '$env_label', expected production"

req=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
lim=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
[[ "$req" == "64Mi" ]] || fail "memory request is '$req', expected 64Mi"
[[ "$lim" == "128Mi" ]] || fail "memory limit is '$lim', expected 128Mi - the JSON 6902 patch must select the Deployment"

body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 "http://scout.$NS/" 2>/dev/null)
grep -q '"version": *"6.14.0"' <<<"$body" || fail "request from shuttle did not return version 6.14.0"

echo "PASS: production serves 6.14.0 with three replicas and a memory limit"
