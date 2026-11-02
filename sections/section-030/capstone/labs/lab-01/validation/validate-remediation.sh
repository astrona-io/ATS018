#!/usr/bin/env bash
# Grades the remediation settings of the existing HelmRelease.
set -u

NS=starfleet
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n $NS get helmrelease relay >/dev/null 2>&1 || fail "HelmRelease relay does not exist in $NS"

get() { kubectl -n $NS get helmrelease relay -o jsonpath="$1"; }

retries=$(get '{.spec.upgrade.remediation.retries}')
[[ "$retries" =~ ^[0-9]+$ && "$retries" -ge 1 ]] || fail "spec.upgrade.remediation.retries is '$retries', expected at least 1"

strategy=$(get '{.spec.upgrade.remediation.strategy}')
[[ -z "$strategy" || "$strategy" == "rollback" ]] || fail "spec.upgrade.remediation.strategy is '$strategy', expected rollback"

last=$(get '{.spec.upgrade.remediation.remediateLastFailure}')
[[ "$last" == "true" ]] || fail "spec.upgrade.remediation.remediateLastFailure is '$last', expected true"

echo "PASS: failed upgrades roll back, retry $retries time(s) and remediate the last failure"
