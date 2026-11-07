#!/usr/bin/env bash
# Grades the cleanup: starfleet holds exactly one Workflow of shuttle-release, and it Succeeded.
set -uo pipefail

NS="starfleet"
TEMPLATE="shuttle-release"
fail() { echo "FAIL: one-run: $*"; exit 1; }

rows=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}|{.spec.workflowTemplateRef.name}|{.status.phase}{"\n"}{end}' 2>/dev/null)
all=$(printf '%s\n' "$rows" | awk -F'|' -v t="$TEMPLATE" '$2 == t {n++} END {print n + 0}')
good=$(printf '%s\n' "$rows" | awk -F'|' -v t="$TEMPLATE" '$2 == t && $3 == "Succeeded" {n++} END {print n + 0}')
[[ "$all" == "1" && "$good" == "1" ]] \
  || fail "$TEMPLATE must have exactly one Workflow left and it must be Succeeded; it has $all, of which $good Succeeded. Delete the others with argo delete"

total=$(printf '%s\n' "$rows" | grep -c '|')
[[ "$total" == "1" ]] || fail "$NS holds $total Workflows; keep only the one Succeeded run of $TEMPLATE"

echo "PASS: one-run: one Succeeded Workflow of $TEMPLATE remains"
