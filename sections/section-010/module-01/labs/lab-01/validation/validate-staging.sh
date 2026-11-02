#!/usr/bin/env bash
# Grades staging by behaviour: the live Deployment and a real request from shuttle.
set -u

NS="starfleet-staging"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get deploy scout >/dev/null 2>&1 || fail "no Deployment scout in $NS - apply the staging overlay"

image=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$image" == "ghcr.io/stefanprodan/podinfo:6.15.0" ]] || fail "staging image is $image, expected ghcr.io/stefanprodan/podinfo:6.15.0"

replicas=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.replicas}')
[[ "$replicas" == "1" ]] || fail "staging runs $replicas replicas, expected 1"

ready=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.status.readyReplicas}')
[[ "$ready" == "1" ]] || fail "staging has $ready ready replicas, expected 1"

env_label=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.metadata.labels.environment}')
[[ "$env_label" == "staging" ]] || fail "label environment is '$env_label', expected staging"

cm=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}')
[[ "$cm" =~ ^scout-settings-.+ ]] || fail "envFrom ConfigMap is '$cm', expected the generated name scout-settings-<hash>"
kubectl -n "$NS" get configmap "$cm" >/dev/null 2>&1 || fail "ConfigMap $cm does not exist in $NS"

body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 "http://scout.$NS/" 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle did not return version 6.15.0"
grep -q '"message": *"staging"' <<<"$body" || fail "request from shuttle did not return message staging"

echo "PASS: staging serves 6.15.0 with message staging"
