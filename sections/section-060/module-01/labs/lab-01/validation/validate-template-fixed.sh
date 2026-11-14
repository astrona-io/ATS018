#!/usr/bin/env bash
# The WorkflowTemplate must be fixed, not replaced by one that skips the clone or the tests.
set -u

fail() { echo "FAIL: $*"; exit 1; }
tpl() { kubectl -n starfleet get workflowtemplate run-tests "$@" 2>/dev/null; }

tpl >/dev/null || fail "no WorkflowTemplate run-tests in starfleet"

path=$(tpl -o jsonpath='{.spec.templates[0].inputs.artifacts[0].path}')
repo=$(tpl -o jsonpath='{.spec.templates[0].inputs.artifacts[0].git.repo}')
dir=$(tpl -o jsonpath='{.spec.templates[0].container.workingDir}')
command=$(tpl -o jsonpath='{.spec.templates[0].container.command[*]}')

[[ "$repo" == "http://gitea-http.gitea.svc:3000/starfleet/scout-app.git" ]] || fail "run-tests no longer clones scout-app (repo: '$repo')"
[[ -n "$path" ]] || fail "run-tests no longer has a git artifact path"
[[ "$dir" == "$path" ]] || fail "workingDir is '$dir' but the repository is cloned to '$path'"
grep -q 'test.sh' <<<"$command" || fail "run-tests no longer runs test.sh (command: '$command')"

echo "PASS: run-tests clones scout-app to $path, starts there and runs test.sh"
