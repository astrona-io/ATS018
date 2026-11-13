#!/usr/bin/env bash
# Grades the cleanup: no failed run of outpost-onboard is left, and successful runs stay.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

rows=$(kubectl -n "$NS" get pipelineruns.tekton.dev -o jsonpath='{range .items[?(@.spec.pipelineRef.name=="outpost-onboard")]}{.metadata.name}{"|"}{.status.conditions[0].status}{"\n"}{end}' 2>/dev/null)
failed=$(printf '%s\n' "$rows" | awk -F'|' '$2 == "False" {print $1}')
good=$(printf '%s\n' "$rows" | awk -F'|' '$2 == "True" {n++} END {print n + 0}')

[[ -z "$failed" ]] || fail "failed PipelineRuns of outpost-onboard remain: $(echo $failed)"
[[ "$good" -ge 2 ]] || fail "keep the Succeeded runs of outpost-onboard; $good remain"

echo "PASS: no failed PipelineRun of outpost-onboard remains"
