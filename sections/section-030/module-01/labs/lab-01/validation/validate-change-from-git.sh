#!/usr/bin/env bash
# Grades the Git change: the commit in Gitea, the revision Flux applied, and the live response.
set -u

fail() { echo "FAIL: $*"; exit 1; }

PORT=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$PORT:3000" >/dev/null 2>&1 &
PF=$!; disown
trap 'kill $PF 2>/dev/null || true' EXIT
API="http://127.0.0.1:$PORT/api/v1"
for i in $(seq 1 30); do curl -fs "$API/version" >/dev/null 2>&1 && break; sleep 1; done

file=$(curl -fs -u platform:starfleet-gitops "$API/repos/starfleet/scout-deploy/raw/overlays/staging/message.yaml?ref=main") \
  || fail "cannot read overlays/staging/message.yaml on branch main"
msg=$(sed -n 's/^ *value: *//p' <<<"$file" | tr -d '"' | head -1)
[[ "$msg" == "staging-v2" ]] || fail "message in Git is '$msg', expected staging-v2 on branch main"

head=$(curl -fs -u platform:starfleet-gitops "$API/repos/starfleet/scout-deploy/branches/main" | sed -n 's/.*"commit":{"id":"\([0-9a-f]\{40\}\)".*/\1/p' | head -1)
[[ -n "$head" ]] || fail "cannot read the head commit of main"

applied=$(kubectl -n flux-system get kustomization scout -o jsonpath='{.status.lastAppliedRevision}' 2>/dev/null)
[[ "$applied" == *"$head" ]] || fail "Flux applied '$applied', Git main head is $head - wait for the reconcile or reconcile the source"

live=$(kubectl -n starfleet-staging get deploy scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}' 2>/dev/null)
[[ "$live" == "$msg" ]] || fail "live message is '$live', Git says '$msg'"

body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 "http://scout.starfleet-staging/" 2>/dev/null)
grep -q "\"message\": *\"$msg\"" <<<"$body" || fail "request from shuttle did not return message '$msg'"

echo "PASS: Git main ($head) applied by Flux, shuttle receives message '$msg'"
