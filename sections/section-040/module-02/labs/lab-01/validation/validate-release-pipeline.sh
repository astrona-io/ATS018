#!/usr/bin/env bash
# Grades the Pipeline and a real run with the scout-ci service account.
set -u

fail() { echo "FAIL: $*"; exit 1; }

tasks=$(kubectl -n starfleet get pipeline scout-release \
  -o jsonpath='{range .spec.tasks[*]}{.taskRef.name}{" "}{end}' 2>/dev/null) \
  || fail "no Pipeline scout-release in starfleet"
for task in fetch-source publish-image update-deploy; do
  grep -qw "$task" <<<"$tasks" || fail "Pipeline scout-release does not run the Task $task (found: $tasks)"
done

after=$(kubectl -n starfleet get pipeline scout-release \
  -o jsonpath='{.spec.tasks[?(@.name=="update-deploy")].runAfter[*]}')
grep -qw publish-image <<<"$after" || fail "update-deploy does not run after publish-image (runAfter: '$after')"

sa_secret=$(kubectl -n starfleet get serviceaccount scout-ci -o jsonpath='{.secrets[*].name}' 2>/dev/null) \
  || fail "no ServiceAccount scout-ci in starfleet"
[[ -n "$sa_secret" ]] || fail "ServiceAccount scout-ci lists no Secret"
for secret in $sa_secret; do
  [[ "$(kubectl -n starfleet get secret "$secret" -o jsonpath='{.metadata.annotations.tekton\.dev/git-0}' 2>/dev/null)" == "http://gitea-http.gitea.svc:3000" ]] \
    && found=yes
done
[[ "${found:-}" == yes ]] || fail "no Secret of scout-ci has the annotation tekton.dev/git-0: http://gitea-http.gitea.svc:3000"

rows=$(kubectl -n starfleet get pipelinerun \
  -o jsonpath='{range .items[?(@.spec.pipelineRef.name=="scout-release")]}{.metadata.name}{"|"}{.status.conditions[0].status}{"|"}{.spec.taskRunTemplate.serviceAccountName}{"|"}{.status.results[0].value}{"\n"}{end}' 2>/dev/null)
good=""
while IFS='|' read -r name status account commit; do
  [[ -n "$name" && "$status" == "True" && "$account" == "scout-ci" && -n "$commit" ]] && good="$name"
done <<<"$rows"
[[ -n "$good" ]] || fail "no Succeeded PipelineRun of scout-release with service account scout-ci and a deploy-commit result"

echo "PASS: scout-release chains the three Tasks and PipelineRun $good Succeeded with scout-ci"
