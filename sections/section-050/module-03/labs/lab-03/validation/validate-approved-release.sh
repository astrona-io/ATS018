#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
[[ "$(kubectl -n starfleet get canary scout -o jsonpath='{.status.phase}')" == Succeeded ]] || fail 'wait for Canary phase Succeeded'
CANARY_UID="$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')"
EVENTS="$(kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" -o jsonpath='{.items[*].message}')"
grep -Fq 'Halt scout.starfleet advancement waiting for approval scout-approval' <<<"$EVENTS" || fail 'the release never waited for approval'
grep -Fq 'Confirm-rollout check scout-approval passed' <<<"$EVENTS" || fail 'the approval never passed'
grep -Fq 'Promotion completed' <<<"$EVENTS" || fail 'wait for the promotion event'
for DEPLOYMENT in scout scout-primary; do
  [[ "$(kubectl -n starfleet get deploy "$DEPLOYMENT" -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].image}')" == ghcr.io/stefanprodan/podinfo:6.15.0 ]] || fail "$DEPLOYMENT must use podinfo 6.15.0"
done
kubectl -n starfleet rollout status deploy/scout-primary --timeout=10s >/dev/null || fail 'primary rollout is not ready'
[[ "$(kubectl -n starfleet get svc scout -o jsonpath='{.spec.selector.app}')" == scout-primary ]] || fail 'keep the public Service selecting primary pods'
GATE_STATUS="$(kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/check)"
[[ "$GATE_STATUS" == 200 ]] || fail 'open the scout approval gate'
BODY="$(kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 10 http://scout.starfleet/)"
grep -Eq '"version": *"6\.15\.0"' <<<"$BODY" || fail 'shuttle must receive version 6.15.0 from the public Service'
echo 'PASS: approved-release'
