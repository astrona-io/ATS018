#!/usr/bin/env bash
# Grades the hand-off: the commit in Git comes from the automation, Flux applied it, and shuttle gets the new version.
set -u

fail() { echo "FAIL: $*"; exit 1; }

PORT=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$PORT:3000" >/dev/null 2>&1 &
PF=$!; disown
WORK="$(mktemp -d)"
trap 'kill $PF 2>/dev/null || true; rm -rf "$WORK"' EXIT
for i in $(seq 1 30); do curl -fs "http://127.0.0.1:$PORT/api/v1/version" >/dev/null 2>&1 && break; sleep 1; done

git clone -q "http://platform:starfleet-gitops@127.0.0.1:$PORT/starfleet/scout-deploy.git" "$WORK/repo" 2>/dev/null \
  || fail "cannot clone starfleet/scout-deploy"
cd "$WORK/repo" || fail "cannot enter the clone"
file=apps/scout/kustomization.yaml

line=$(grep 'newTag:' "$file")
grep -q 'newTag: 6.15.0' <<<"$line" || fail "$file on main has '$line', expected newTag: 6.15.0"
grep -q '\$imagepolicy.*flux-system:scout:tag' <<<"$line" || fail "the setter marker with flux-system:scout:tag is missing on the newTag line"

author=$(git log -1 --format=%an -- "$file")
[[ "$author" == "fluxcdbot" ]] || fail "the newest commit of $file is by '$author', expected the automation author fluxcdbot - do not edit the tag by hand"

head=$(git rev-parse HEAD)
applied=$(kubectl -n flux-system get kustomization scout -o jsonpath='{.status.lastAppliedRevision}' 2>/dev/null)
[[ "$applied" == *"$head" ]] || fail "Flux applied '$applied', Git main head is $head - wait for the reconcile"

image=$(kubectl -n starfleet get deploy scout -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[[ "$image" == "registry.registry.svc:5000/starfleet/scout:6.15.0" ]] || fail "Deployment scout runs image '$image'"
ready=$(kubectl -n starfleet get deploy scout -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ "$ready" == "1" ]] || fail "Deployment scout has '$ready' ready replicas, expected 1"

body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 http://scout.starfleet.svc/ 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle did not return version 6.15.0"

echo "PASS: fluxcdbot committed 6.15.0 to Git ($head), Flux applied it, shuttle receives 6.15.0"
