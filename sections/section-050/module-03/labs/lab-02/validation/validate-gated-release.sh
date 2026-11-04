#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
CANARY_UID="$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')" || fail 'create the scout Canary'
EVENTS="$(kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" -o jsonpath='{range .items[*]}{.message}{"\n"}{end}')"
grep -q 'pre-rollout check scout-http-check failed' <<<"$EVENTS" || fail 'no failed HTTP gate event'
# Flagger drops the load tester's response body on a 5xx, so the event never shows curl's error.
# The load tester logs it. curl exits with status 22 when -f sees an HTTP error.
LOADTESTER_LOG="$(kubectl -n starfleet logs deploy/flagger-loadtester)"
grep -F 'command failed curl -fsS --max-time 3 http://scout-canary.starfleet/status/500' <<<"$LOADTESTER_LOG" | grep -q 'exit status 22' || fail 'the load tester log has no failed curl to /status/500'
template_messages() {
  kubectl -n starfleet get rs -l "app=$1" -o jsonpath='{range .items[*]}{.spec.template.spec.containers[?(@.name=="scout")].env[?(@.name=="PODINFO_UI_MESSAGE")].value}{"\n"}{end}'
}
grep -qx blocked <<<"$(template_messages scout)" || fail 'scout never had PODINFO_UI_MESSAGE=blocked in its pod template'
! grep -qx blocked <<<"$(template_messages scout-primary)" || fail 'the blocked template must never reach scout-primary'
grep -q 'Rolling back scout.starfleet failed checks threshold reached 2' <<<"$EVENTS" || fail 'no threshold rollback'
grep -q 'Pre-rollout check scout-http-check passed' <<<"$EVENTS" || fail 'no passing gate event'
grep -q 'Advance scout.starfleet canary iteration 3/3' <<<"$EVENTS" || fail 'three iterations did not complete'
grep -q 'Promotion completed' <<<"$EVENTS" || fail 'no promotion event'
[[ "$(kubectl -n starfleet get canary scout -o jsonpath='{.status.phase}')" == Succeeded ]] || fail 'Canary must be Succeeded'
for DEPLOYMENT in scout scout-primary; do
  [[ "$(kubectl -n starfleet get deploy "$DEPLOYMENT" -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')" == green ]] || fail "$DEPLOYMENT must have the green environment value"
  [[ "$(kubectl -n starfleet get deploy "$DEPLOYMENT" -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].image}')" == ghcr.io/stefanprodan/podinfo:6.15.0 ]] || fail 'keep the original image; release by environment change'
done
[[ "$(kubectl -n starfleet get svc scout -o jsonpath='{.spec.selector.app}')" == scout-primary ]] || fail 'scout Service must select primary pods'
BODY="$(kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 10 http://scout.starfleet/)"
grep -q '"message": *"green"' <<<"$BODY" || fail 'shuttle must receive green'
echo 'PASS: gated-release'
