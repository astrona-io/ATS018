#!/usr/bin/env bash
# A real push must have started a Workflow through the Sensor, and it must have Succeeded.
set -u

fail() { echo "FAIL: $*"; exit 1; }
GITEA=http://gitea-http.gitea.svc:3000/api/v1/repos/starfleet/scout-app

commits=$(kubectl -n starfleet exec deploy/shuttle -- curl -s "$GITEA/commits?sha=main&limit=1&stat=false&verification=false&files=false" 2>/dev/null)
head_sha=$(grep -Eo '"sha": *"[0-9a-f]{40}"' <<<"$commits" | head -1 | grep -Eo '[0-9a-f]{40}')
[[ -n "$head_sha" ]] || fail "cannot read the newest commit of scout-app"
if grep -q 'Initial content of scout-app' <<<"$commits"; then
  fail "main of scout-app has no new commit; push a change to main after the Sensor runs"
fi

rows=$(kubectl -n starfleet get workflows \
  -o jsonpath='{range .items[?(@.metadata.labels.events\.argoproj\.io/sensor=="push-ci")]}{.metadata.name}{"|"}{.status.phase}{"|"}{.spec.arguments.parameters[0].value}{"\n"}{end}' 2>/dev/null)
[[ -n "$rows" ]] || fail "no Workflow was created by the Sensor push-ci"

good=""
while IFS='|' read -r name phase revision; do
  [[ -n "$name" && "$phase" == "Succeeded" && "$revision" == "$head_sha" ]] && good="$name"
done <<<"$rows"
[[ -n "$good" ]] || fail "no Succeeded Workflow from the Sensor has revision $head_sha (the newest commit on main). Found: $rows"

echo "PASS: Workflow $good, started by the Sensor for commit ${head_sha:0:7}, Succeeded"
