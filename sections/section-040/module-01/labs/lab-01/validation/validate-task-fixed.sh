#!/usr/bin/env bash
# The Task must be fixed, not deleted or replaced by a step that skips the tests.
set -u

fail() { echo "FAIL: $*"; exit 1; }

kubectl -n starfleet get task run-tests >/dev/null 2>&1 || fail "Task run-tests does not exist in starfleet"

dir=$(kubectl -n starfleet get task run-tests -o jsonpath='{.spec.steps[0].workingDir}')
case "$dir" in
  '$(workspaces.source.path)'|/workspace/source) ;;
  *) fail "step 0 of run-tests starts in '$dir', expected the source workspace" ;;
esac

script=$(kubectl -n starfleet get task run-tests -o jsonpath='{.spec.steps[*].script}')
grep -q 'test.sh' <<<"$script" || fail "the run-tests Task no longer runs test.sh"

pipeline_tasks=$(kubectl -n starfleet get pipeline scout-ci -o jsonpath='{range .spec.tasks[*]}{.taskRef.name}{" "}{end}' 2>/dev/null)
[[ "$pipeline_tasks" == "fetch-source run-tests " ]] \
  || fail "Pipeline scout-ci must still run fetch-source and run-tests, found: $pipeline_tasks"

echo "PASS: run-tests starts in the workspace, still runs test.sh, and scout-ci still uses it"
