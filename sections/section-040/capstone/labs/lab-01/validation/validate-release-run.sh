#!/usr/bin/env bash
# Grades a real run: Succeeded, with scout-ci, and the tests finished before
# the image was published.
set -u

fail() { echo "FAIL: $*"; exit 1; }

rows=$(kubectl -n starfleet get pipelinerun \
  -o jsonpath='{range .items[?(@.spec.pipelineRef.name=="scout-release")]}{.metadata.name}{"|"}{.status.conditions[0].status}{"|"}{.spec.taskRunTemplate.serviceAccountName}{"|"}{.status.results[0].value}{"\n"}{end}' 2>/dev/null)
good=""
while IFS='|' read -r name status account commit; do
  [[ -n "$name" && "$status" == "True" && "$account" == "scout-ci" && -n "$commit" ]] && good="$name"
done <<<"$rows"
[[ -n "$good" ]] || fail "no Succeeded PipelineRun of scout-release with service account scout-ci and a deploy-commit result"

task_field() {
  kubectl -n starfleet get taskrun -l "tekton.dev/pipelineRun=$good,tekton.dev/pipelineTask=$1" \
    -o jsonpath="{.items[0].$2}" 2>/dev/null
}
dir=$(task_field run-tests status.taskSpec.steps[0].workingDir)
case "$dir" in
  '$(workspaces.source.path)'|/workspace/source) ;;
  *) fail "the run-tests TaskRun of $good ran in '$dir', not in the source workspace" ;;
esac
[[ "$(task_field run-tests status.steps[0].terminated.exitCode)" == "0" ]] \
  || fail "the test step of $good did not exit with 0"

tests_done=$(task_field run-tests status.completionTime)
published=$(task_field publish-image status.startTime)
[[ -n "$tests_done" && -n "$published" && ! "$published" < "$tests_done" ]] \
  || fail "publish-image started ($published) before run-tests finished ($tests_done)"

echo "PASS: PipelineRun $good Succeeded with scout-ci and the tests passed before the image was published"
