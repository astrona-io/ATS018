#!/usr/bin/env bash
# Grades the run: one Succeeded Workflow from scout-check ran both steps in one StepGroup node.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

rows=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}|{.spec.workflowTemplateRef.name}|{.status.phase}{"\n"}{end}' 2>/dev/null)
names=$(printf '%s\n' "$rows" | awk -F'|' '$2 == "scout-check" && $3 == "Succeeded" {print $1}')
[[ -n "$names" ]] || fail "no Succeeded Workflow from the WorkflowTemplate scout-check in $NS"

for name in $names; do
  nodes=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{range .status.nodes.*}{.id}|{.type}|{.displayName}|{.phase}|{.children[*]}{"\n"}{end}')
  original=$(printf '%s\n' "$nodes" | awk -F'|' '$2 == "Pod" && $3 == "check-version" && $4 == "Succeeded" {print $1}')
  copy=$(printf '%s\n' "$nodes" | awk -F'|' '$2 == "Pod" && $3 == "check-version-copy" && $4 == "Succeeded" {print $1}')
  [[ -n "$original" && -n "$copy" ]] || continue
  if printf '%s\n' "$nodes" | awk -F'|' -v a="$original" -v b="$copy" '
    $2 == "StepGroup" {
      count = split($5, children, " ")
      seen_a = 0; seen_b = 0
      for (i = 1; i <= count; i++) { if (children[i] == a) seen_a = 1; if (children[i] == b) seen_b = 1 }
      if (seen_a && seen_b) found = 1
    }
    END { exit found ? 0 : 1 }'; then
    echo "PASS: $name ran both check steps in one group and Succeeded"
    exit 0
  fi
done

fail "no Succeeded run of scout-check ran both steps in one group; submit a new run after the template change"
