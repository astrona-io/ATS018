#!/usr/bin/env bash
# Grades the cleanup: starfleet holds one Succeeded Workflow per WorkflowTemplate and nothing else.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

rows=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}|{.spec.workflowTemplateRef.name}|{.status.phase}{"\n"}{end}' 2>/dev/null)
total=$(printf '%s\n' "$rows" | grep -c '|')

for template in scout-check outpost-config; do
  all=$(printf '%s\n' "$rows" | awk -F'|' -v t="$template" '$2 == t {n++} END {print n + 0}')
  good=$(printf '%s\n' "$rows" | awk -F'|' -v t="$template" '$2 == t && $3 == "Succeeded" {n++} END {print n + 0}')
  [[ "$all" == "1" && "$good" == "1" ]] || fail "$template must have exactly one Workflow left and it must be Succeeded; it has $all, of which $good Succeeded"
done

[[ "$total" == "2" ]] || fail "$NS holds $total Workflows; keep only the one Succeeded run of each WorkflowTemplate"

echo "PASS: one Succeeded Workflow remains for each WorkflowTemplate"
