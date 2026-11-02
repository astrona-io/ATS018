#!/usr/bin/env bash
# Grades a real run: a successful PipelineRun of scout-ci whose run-tests
# TaskRun used the fixed step.
set -u

fail() { echo "FAIL: $*"; exit 1; }

rows=$(kubectl -n starfleet get pipelinerun \
  -o jsonpath='{range .items[?(@.spec.pipelineRef.name=="scout-ci")]}{.metadata.name}{"|"}{.status.conditions[0].status}{"|"}{.status.results[0].name}{"="}{.status.results[0].value}{"\n"}{end}' 2>/dev/null) \
  || fail "cannot list PipelineRuns"

good=""
while IFS='|' read -r name status result; do
  [[ -n "$name" && "$status" == "True" && "$result" == "version=6.15.0" ]] && good="$name"
done <<<"$rows"
[[ -n "$good" ]] || fail "no Succeeded PipelineRun of scout-ci with the result version=6.15.0"

selector="tekton.dev/pipelineRun=$good,tekton.dev/pipelineTask=run-tests"
dir=$(kubectl -n starfleet get taskrun -l "$selector" -o jsonpath='{.items[0].status.taskSpec.steps[0].workingDir}' 2>/dev/null)
case "$dir" in
  '$(workspaces.source.path)'|/workspace/source) ;;
  *) fail "the run-tests TaskRun of $good ran in '$dir', not in the source workspace" ;;
esac
code=$(kubectl -n starfleet get taskrun -l "$selector" -o jsonpath='{.items[0].status.steps[0].terminated.exitCode}' 2>/dev/null)
[[ "$code" == "0" ]] || fail "the test step of $good did not exit with 0"

echo "PASS: PipelineRun $good Succeeded, tests ran in the workspace, version 6.15.0"
