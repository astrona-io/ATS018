#!/usr/bin/env bash
# The workflow pods' service account must be able to write task results, and
# must not have been given broad rights to get there.
set -u

fail() { echo "FAIL: $*"; exit 1; }
AS=system:serviceaccount:starfleet:workflow-runner

sa=$(kubectl -n starfleet get workflowtemplate run-tests -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[[ "$sa" == "workflow-runner" ]] || fail "run-tests must keep running as workflow-runner (found '$sa')"

for verb in create patch; do
  [[ "$(kubectl auth can-i "$verb" workflowtaskresults.argoproj.io -n starfleet --as="$AS" 2>/dev/null)" == "yes" ]] \
    || fail "workflow-runner cannot $verb workflowtaskresults in starfleet"
done

[[ "$(kubectl auth can-i '*' '*' -n starfleet --as="$AS" 2>/dev/null)" == "no" ]] \
  || fail "workflow-runner has full rights in starfleet; grant only workflowtaskresults"
[[ "$(kubectl auth can-i delete pods -n starfleet --as="$AS" 2>/dev/null)" == "no" ]] \
  || fail "workflow-runner may delete pods; grant only workflowtaskresults"

echo "PASS: workflow-runner can write workflowtaskresults and nothing broad"
