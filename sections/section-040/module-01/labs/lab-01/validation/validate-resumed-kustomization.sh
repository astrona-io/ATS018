#!/usr/bin/env bash
# Grades the suspended Kustomization: nothing in flux-system stays suspended, and
# the workload it delivers matches Git again. Failure messages for a suspended
# object do not name it, because finding it is part of the task.
set -u

fail() { echo "FAIL: $*"; exit 1; }
flux_get() { kubectl -n flux-system get "$@" 2>/dev/null; }

expected_message="production"

suspended=$(flux_get kustomizations -o jsonpath='{range .items[*]}{.spec.suspend}{"\n"}{end}')
if grep -qx "true" <<<"$suspended"; then
  fail "a Kustomization in flux-system is still suspended"
fi

# Deleting or repointing the object hides the suspension instead of fixing it.
flux_get kustomization scout-production >/dev/null \
  || fail "a Kustomization that existed at the start is missing from flux-system"
[[ "$(flux_get kustomization scout-production -o jsonpath='{.spec.path}')" == "./overlays/production" ]] \
  || fail "Kustomization scout-production must keep the path ./overlays/production"
[[ "$(flux_get kustomization scout-production -o jsonpath='{.spec.sourceRef.name}')" == "scout-production" ]] \
  || fail "Kustomization scout-production must keep its source"
[[ "$(flux_get kustomization scout-production -o jsonpath='{.spec.prune}')" == "true" ]] \
  || fail "Kustomization scout-production must keep prune: true"

for name in $(flux_get kustomizations -o jsonpath='{.items[*].metadata.name}'); do
  [[ "$(flux_get kustomization "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == "True" ]] \
    || fail "Kustomization $name is not Ready"
done

# Changing Git to match the drift is the wrong fix: Git must keep its value.
PORT=$((30000 + RANDOM % 20000))
kubectl -n gitea port-forward svc/gitea-http "$PORT:3000" >/dev/null 2>&1 &
PF=$!; disown
trap 'kill $PF 2>/dev/null || true' EXIT
API="http://127.0.0.1:$PORT/api/v1"
for i in $(seq 1 30); do curl -fs "$API/version" >/dev/null 2>&1 && break; sleep 1; done

file=$(curl -fs -u platform:starfleet-gitops "$API/repos/starfleet/scout-deploy/raw/overlays/production/message.yaml?ref=main") \
  || fail "cannot read overlays/production/message.yaml on branch main"
git_message=$(sed -n 's/^ *value: *//p' <<<"$file" | tr -d '"' | head -1)
[[ "$git_message" == "$expected_message" ]] \
  || fail "message in Git is '$git_message': correct the drift in the cluster, do not change Git to match it"

# Old pods can answer for a short time after the controller corrects the Deployment.
live=""
body=""
for i in $(seq 1 10); do
  live=$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}' 2>/dev/null)
  body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 "http://scout.starfleet-production/" 2>/dev/null)
  [[ "$live" == "$expected_message" ]] && grep -q "\"message\": *\"$expected_message\"" <<<"$body" && break
  sleep 3
done
[[ "$live" == "$expected_message" ]] || fail "live message is '$live', Git says '$expected_message'"
grep -q "\"message\": *\"$expected_message\"" <<<"$body" \
  || fail "request from shuttle did not return message '$expected_message'"

echo "PASS: no Kustomization is suspended, all are Ready, and the drift is corrected from Git"
