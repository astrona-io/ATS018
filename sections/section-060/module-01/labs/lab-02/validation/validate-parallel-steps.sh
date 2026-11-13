#!/usr/bin/env bash
# Grades the step order: prepare alone, then the two checks in one group of the steps list.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get workflowtemplate scout-check >/dev/null 2>&1 || fail "no WorkflowTemplate scout-check in $NS"

groups=$(kubectl -n "$NS" get workflowtemplate scout-check -o jsonpath='{range .spec.templates[?(@.name=="main")].steps[*]}{range @[*]}{.name}:{.template},{end}{"\n"}{end}')
[[ -n "$groups" ]] || fail "the template main of scout-check must keep its steps list"

group_count=$(printf '%s\n' "$groups" | wc -l | tr -d ' ')
[[ "$group_count" == "2" ]] || fail "the steps list of main must have two groups, not $group_count"

first=$(printf '%s\n' "$groups" | sed -n 1p)
second=$(printf '%s\n' "$groups" | sed -n 2p)
[[ "$first" == "prepare:prepare," ]] || fail "the first group must hold only the step prepare"

case "$second" in
  "check-version:check-version,check-version-copy:check-version,") ;;
  "check-version-copy:check-version,check-version:check-version,") ;;
  *) fail "the second group must hold exactly check-version and check-version-copy, and both must use the template check-version" ;;
esac

echo "PASS: check-version and check-version-copy share one step group"
