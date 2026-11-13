#!/usr/bin/env bash
# History comes from Helm's live release storage, not a learner-supplied transcript.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
fail() { echo "FAIL: rollback: $*"; exit 1; }
LATEST="$(helm history scout -n starfleet-production --max 1 -o json)" || fail "no release history"
grep -Eq '"rollback_revision"[[:space:]]*:[[:space:]]*2([,}[:space:]])' <<<"$LATEST" || fail "latest operation must roll back to revision 2"
grep -Eq '"status"[[:space:]]*:[[:space:]]*"deployed"' <<<"$LATEST" || fail "rollback is not deployed"
INITIAL="$(helm get values scout -n starfleet-production --revision 1 --all -o yaml)" || fail "missing initial revision"
grep -q '6.14.0' <<<"$INITIAL" || fail "install the starter before upgrading"
BASELINE="$(helm get values scout -n starfleet-production --revision 2 --all -o yaml)" || fail "missing good revision"
grep -qx 'message: release-ready' <<<"$BASELINE" || fail "revision 2 needs the release-ready message"
CHANGED="$(helm get values scout -n starfleet-production --revision 3 --all -o yaml)" || fail "missing temporary upgrade"
grep -qx 'message: temporary' <<<"$CHANGED" || fail "revision 3 needs the temporary message"


IMAGE="$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.spec.template.spec.containers[0].image}')" || fail "no scout Deployment"
[[ "$IMAGE" == ghcr.io/stefanprodan/podinfo:6.15.0 ]] || fail "wrong scout image"
PROBE="$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')"
[[ "$PROBE" == /readyz ]] || fail "keep the starter readiness probe"
SELECTOR="$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.spec.selector.matchLabels.app\.kubernetes\.io/instance}')"
LABEL="$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.spec.template.metadata.labels.app\.kubernetes\.io/instance}')"
[[ "$SELECTOR" == scout && "$LABEL" == scout ]] || fail "keep the release labels and selector"
REPLICAS="$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.spec.replicas}')"
READY="$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.status.readyReplicas}')"
[[ "$REPLICAS" == 2 && "$READY" == 2 ]] || fail "need 2 ready replicas"
MESSAGE="$(kubectl -n starfleet-production get deploy scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')"
[[ "$MESSAGE" == release-ready ]] || fail "set PODINFO_UI_MESSAGE through the template and values"
# Right after a rollout or rollback the Service can still send a request to a
# terminating pod, so poll until the response matches or the attempts run out.
BODY=""
for attempt in $(seq 1 10); do
  BODY="$(kubectl -n starfleet exec deploy/shuttle -- curl -fsS --max-time 10 http://scout.starfleet-production/ 2>/dev/null)" || BODY=""
  if grep -Eq '"version": *"6.15.0"' <<<"$BODY" && grep -Eq '"message": *"release-ready"' <<<"$BODY"; then break; fi
  [[ "$attempt" -lt 10 ]] && sleep 2
done
[[ -n "$BODY" ]] || fail "request from shuttle failed"
grep -Eq '"version": *"6.15.0"' <<<"$BODY" || fail "response version differs"
grep -Eq '"message": *"release-ready"' <<<"$BODY" || fail "response message differs"
echo "PASS: rollback restores the working release and response"
