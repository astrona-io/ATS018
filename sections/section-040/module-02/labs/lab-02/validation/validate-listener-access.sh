#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: listener-access — $*"; exit 1; }
fields=$(kubectl -n starfleet get eventlistener scout-push -o jsonpath='{.spec.serviceAccountName}|{.spec.triggers[?(@.name=="push")].bindings[*].ref}|{.spec.triggers[?(@.name=="push")].template.ref}') || fail 'keep EventListener scout-push'
[[ "$fields" == 'scout-listener|scout-push|scout-check' ]] || fail 'wire push to scout-push and scout-check, using scout-listener'
identity=system:serviceaccount:starfleet:scout-listener
for resource in eventlisteners.triggers.tekton.dev triggerbindings.triggers.tekton.dev triggertemplates.triggers.tekton.dev; do
  for verb in get list watch; do
    kubectl -n starfleet auth can-i "$verb" "$resource" --as="$identity" --quiet || fail "scout-listener cannot $verb $resource"
  done
done
kubectl -n starfleet auth can-i create pipelineruns.tekton.dev --as="$identity" --quiet || fail 'scout-listener cannot create PipelineRuns'
kubectl -n starfleet get serviceaccount scout-runner >/dev/null || fail 'keep scout-runner'
echo 'PASS: listener-access'
