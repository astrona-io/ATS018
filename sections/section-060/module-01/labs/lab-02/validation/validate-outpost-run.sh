#!/usr/bin/env bash
# Grades the parameter and the account: the objects in outpost come from a run with both set right.
set -u

NS="starfleet"
TARGET="outpost"
ACCOUNT="outpost-provisioner"
fail() { echo "FAIL: $*"; exit 1; }

rows=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}|{.spec.workflowTemplateRef.name}|{.status.phase}{"\n"}{end}' 2>/dev/null)
names=$(printf '%s\n' "$rows" | awk -F'|' '$2 == "outpost-config" && $3 == "Succeeded" {print $1}')
[[ -n "$names" ]] || fail "no Succeeded Workflow from the WorkflowTemplate outpost-config in $NS"

reason="the Succeeded run of outpost-config has the wrong settings"
for name in $names; do
  param=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{.spec.arguments.parameters[?(@.name=="target-namespace")].value}')
  if [[ "$param" != "$TARGET" ]]; then
    reason="$name did not receive target-namespace=$TARGET"
    continue
  fi

  accounts=$(kubectl -n "$NS" get pods -l "workflows.argoproj.io/workflow=$name" -o jsonpath='{range .items[*]}{.spec.serviceAccountName}{"\n"}{end}')
  if [[ -z "$accounts" ]] || printf '%s\n' "$accounts" | grep -qvx "$ACCOUNT"; then
    reason="the pods of $name did not all run as $ACCOUNT"
    continue
  fi

  settings=$(kubectl -n "$TARGET" get configmap scout-settings -o jsonpath='{.metadata.labels.created-by-workflow}' 2>/dev/null)
  account=$(kubectl -n "$TARGET" get serviceaccount scout -o jsonpath='{.metadata.labels.created-by-workflow}' 2>/dev/null)
  if [[ "$settings" != "$name" || "$account" != "$name" ]]; then
    reason="the ConfigMap scout-settings and the ServiceAccount scout in $TARGET must come from the run you keep"
    continue
  fi

  echo "PASS: $name created the objects in $TARGET as $ACCOUNT"
  exit 0
done

fail "$reason"
