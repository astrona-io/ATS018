#!/usr/bin/env bash
# Grades the run: a Succeeded Workflow from shuttle-release ran the new step after fetch-manifest
# ended and before deploy started.
set -uo pipefail

NS="starfleet"
TEMPLATE="shuttle-release"
fail() { echo "FAIL: workflow-succeeded: $*"; exit 1; }

rows=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}|{.spec.workflowTemplateRef.name}|{.status.phase}{"\n"}{end}' 2>/dev/null)
names=$(printf '%s\n' "$rows" | awk -F'|' -v t="$TEMPLATE" '$2 == t && $3 == "Succeeded" {print $1}')
[[ -n "$names" ]] || fail "no Succeeded Workflow from the WorkflowTemplate $TEMPLATE in $NS; run it with argo submit --from workflowtemplate/$TEMPLATE"

# One line per Pod node: step name|phase|startedAt|finishedAt. Timestamps are RFC 3339 in UTC,
# so string order is time order.
node_line() { printf '%s\n' "$2" | awk -F'|' -v n="$1" '$1 == n {print; exit}'; }
for name in $names; do
  nodes=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{range .status.nodes.*}{.displayName}|{.phase}|{.startedAt}|{.finishedAt}|{.type}{"\n"}{end}' 2>/dev/null | awk -F'|' '$5 == "Pod"')
  fetch=$(node_line fetch-manifest "$nodes")
  verify=$(node_line verify-checksum "$nodes")
  deploy=$(node_line deploy "$nodes")
  notify=$(node_line notify "$nodes")
  [[ -n "$fetch" && -n "$verify" && -n "$deploy" && -n "$notify" ]] || continue
  for line in "$fetch" "$verify" "$deploy" "$notify"; do
    [[ "$(printf '%s' "$line" | cut -d'|' -f2)" == "Succeeded" ]] || continue 2
  done
  fetch_end=$(printf '%s' "$fetch" | cut -d'|' -f4)
  verify_start=$(printf '%s' "$verify" | cut -d'|' -f3)
  verify_end=$(printf '%s' "$verify" | cut -d'|' -f4)
  deploy_start=$(printf '%s' "$deploy" | cut -d'|' -f3)
  if [[ "$verify_start" > "$fetch_end" || "$verify_start" == "$fetch_end" ]] \
    && [[ "$deploy_start" > "$verify_end" || "$deploy_start" == "$verify_end" ]]; then
    echo "PASS: workflow-succeeded: $name ran verify-checksum between fetch-manifest and deploy"
    exit 0
  fi
done

fail "no Succeeded run of $TEMPLATE ran verify-checksum after fetch-manifest and before deploy; change the template, then start a new run"
