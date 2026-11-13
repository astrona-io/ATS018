#!/usr/bin/env bash
# Grades the repair: the template reads a file the ConfigMap provides and still does the comparison.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get workflowtemplate scout-check >/dev/null 2>&1 || fail "no WorkflowTemplate scout-check in $NS"

[[ "$(kubectl -n "$NS" get configmap scout-release -o jsonpath='{.data.VERSION}' 2>/dev/null)" == "6.15.0" ]] \
  || fail "the ConfigMap scout-release must stay as it was"
[[ "$(kubectl -n "$NS" get workflowtemplate scout-check -o jsonpath='{.spec.volumes[?(@.name=="release")].configMap.name}')" == "scout-release" ]] \
  || fail "scout-check must still mount the ConfigMap scout-release"
[[ -z "$(kubectl -n "$NS" get workflowtemplate scout-check -o jsonpath='{.spec.volumes[?(@.name=="release")].configMap.items}')" ]] \
  || fail "keep the volume as it was and fix the command instead"
[[ "$(kubectl -n "$NS" get workflowtemplate scout-check -o jsonpath='{.spec.arguments.parameters[?(@.name=="expected-version")].value}')" == "6.15.0" ]] \
  || fail "keep the expected-version argument of scout-check at its starting value"

command_text=$(kubectl -n "$NS" get workflowtemplate scout-check -o jsonpath='{.spec.templates[?(@.name=="check-version")].container.command[*]} {.spec.templates[?(@.name=="check-version")].container.args[*]}')
[[ "$command_text" == *grep* && "$command_text" == *'workflow.parameters.expected-version'* ]] \
  || fail "the check-version template must still compare the expected version with grep"

file_pattern='/release/VERSION([^[:alnum:]_.-]|$)'
[[ "$command_text" =~ $file_pattern ]] || fail "the check-version template still reads a path the mounted ConfigMap does not provide"

echo "PASS: the check-version template reads the mounted file"
