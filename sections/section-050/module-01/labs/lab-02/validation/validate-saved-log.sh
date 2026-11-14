#!/usr/bin/env bash
# Grades the saved log against the live run: only tkn writes these prefixes, and the
# TaskRun names exist only in the log of a real run of the site rigel.
set -u

NS="starfleet"
LOG_FILE="/tmp/outpost-rigel-run.log"
fail() { echo "FAIL: $*"; exit 1; }

[[ -s "$LOG_FILE" ]] || fail "$LOG_FILE does not exist or is empty"

names=$(kubectl -n "$NS" get pipelineruns.tekton.dev -o jsonpath='{range .items[?(@.spec.pipelineRef.name=="outpost-onboard")]}{.metadata.name}{"|"}{.status.conditions[0].status}{"|"}{.spec.params[?(@.name=="site")].value}{"\n"}{end}' 2>/dev/null | awk -F'|' '$2 == "True" && $3 == "rigel" {print $1}')
[[ -n "$names" ]] || fail "no Succeeded PipelineRun of outpost-onboard for the site rigel to compare the file with"

for name in $names; do
  report=$(kubectl -n "$NS" get taskruns.tekton.dev -l "tekton.dev/pipelineRun=$name,tekton.dev/pipelineTask=report-namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  label=$(kubectl -n "$NS" get taskruns.tekton.dev -l "tekton.dev/pipelineRun=$name,tekton.dev/pipelineTask=label-namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [[ -n "$report" && -n "$label" ]] || continue
  if grep -F '[report-namespace : report]' "$LOG_FILE" | grep -Fq "reported by $report" \
    && grep -F '[label-namespace : label]' "$LOG_FILE" | grep -Fq "labelled by $label"; then
    echo "PASS: $LOG_FILE holds the tkn log of $name"
    exit 0
  fi
done

fail "$LOG_FILE does not hold the complete tkn pipelinerun logs output of a Succeeded run for the site rigel"
