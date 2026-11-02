#!/usr/bin/env bash
# Grades the two outputs of the pipeline: the registry tag and the Git commit.
set -u

fail() { echo "FAIL: $*"; exit 1; }
shuttle_curl() { kubectl -n starfleet exec deploy/shuttle -- curl -s "$@" 2>/dev/null; }
GITEA=http://gitea-http.gitea.svc:3000/api/v1/repos/starfleet/scout-deploy

tags=$(shuttle_curl http://registry.registry.svc:5000/v2/starfleet/scout/tags/list)
grep -q '"6.15.0"' <<<"$tags" || fail "the registry has no starfleet/scout:6.15.0 (tags: $tags)"

kustomization=$(shuttle_curl -u platform:starfleet-gitops "$GITEA/raw/kustomization.yaml?ref=main")
grep -Eq 'newTag: *6\.15\.0' <<<"$kustomization" || fail "kustomization.yaml on main of scout-deploy does not set newTag: 6.15.0"

commits=$(shuttle_curl -u platform:starfleet-gitops "$GITEA/commits?sha=main&limit=1&stat=false&verification=false&files=false")
head_sha=$(grep -Eo '"sha": *"[0-9a-f]{40}"' <<<"$commits" | head -1 | grep -Eo '[0-9a-f]{40}')
[[ -n "$head_sha" ]] || fail "cannot read the newest commit of scout-deploy"
grep -q 'Deploy scout 6.15.0' <<<"$commits" || fail "the newest commit of scout-deploy is not 'Deploy scout 6.15.0'"

results=$(kubectl -n starfleet get pipelinerun \
  -o jsonpath='{range .items[?(@.spec.pipelineRef.name=="scout-release")]}{.status.results[0].value}{"\n"}{end}' 2>/dev/null)
grep -qx "$head_sha" <<<"$results" || fail "no PipelineRun of scout-release reports the newest commit $head_sha as its deploy-commit; the commit must come from the pipeline"

echo "PASS: scout:6.15.0 is in the registry and the pipeline pushed commit ${head_sha:0:7} that sets newTag 6.15.0"
