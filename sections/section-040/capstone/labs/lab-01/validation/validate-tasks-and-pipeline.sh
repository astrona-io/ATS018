#!/usr/bin/env bash
# Grades the fixed objects: the Task is repaired (not removed or emptied), the
# Pipeline keeps all four Tasks in the right order, and scout-ci has Git credentials.
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

tasks=$(kubectl -n starfleet get pipeline scout-release \
  -o jsonpath='{range .spec.tasks[*]}{.taskRef.name}{" "}{end}' 2>/dev/null) \
  || fail "no Pipeline scout-release in starfleet"
for task in fetch-source run-tests publish-image update-deploy; do
  grep -qw "$task" <<<"$tasks" || fail "Pipeline scout-release does not run the Task $task (found: $tasks)"
done

run_after() {
  kubectl -n starfleet get pipeline scout-release \
    -o jsonpath="{.spec.tasks[?(@.name==\"$1\")].runAfter[*]}"
}
grep -qw run-tests <<<"$(run_after publish-image)" \
  || fail "publish-image does not run after run-tests (runAfter: '$(run_after publish-image)')"
grep -qw publish-image <<<"$(run_after update-deploy)" \
  || fail "update-deploy does not run after publish-image (runAfter: '$(run_after update-deploy)')"

version=$(kubectl -n starfleet get pipeline scout-release \
  -o jsonpath='{.spec.tasks[?(@.name=="publish-image")].params[?(@.name=="version")].value}')
[[ "$version" == '$(tasks.fetch-source.results.version)' ]] \
  || fail "publish-image gets the version '$version', expected the version result of fetch-source"

sa_secret=$(kubectl -n starfleet get serviceaccount scout-ci -o jsonpath='{.secrets[*].name}' 2>/dev/null) \
  || fail "no ServiceAccount scout-ci in starfleet"
[[ -n "$sa_secret" ]] || fail "ServiceAccount scout-ci lists no Secret"
for secret in $sa_secret; do
  [[ "$(kubectl -n starfleet get secret "$secret" -o jsonpath='{.metadata.annotations.tekton\.dev/git-0}' 2>/dev/null)" == "http://gitea-http.gitea.svc:3000" ]] \
    && found=yes
done
[[ "${found:-}" == yes ]] || fail "no Secret of scout-ci has the annotation tekton.dev/git-0: http://gitea-http.gitea.svc:3000"

echo "PASS: run-tests starts in the workspace, the Pipeline orders the four Tasks and scout-ci has Git credentials"
