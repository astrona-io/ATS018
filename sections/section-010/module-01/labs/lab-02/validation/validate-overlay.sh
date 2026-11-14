#!/usr/bin/env bash
# Read the workload, generated configuration and response; compare source with live state.
set -euo pipefail
fail() { echo "FAIL: overlay: $*"; exit 1; }
OVERLAY="$HOME/resources/scout/overlays/staging"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for FILE in deployment.yaml service.yaml kustomization.yaml; do
  cmp -s "$HOME/resources/scout/base/$FILE" "$SCRIPT_DIR/../resources/scout/base/$FILE" || fail "keep base/$FILE unchanged"
done
kubectl -n starfleet-staging get deploy scout >/dev/null || fail "apply the staging overlay"
IMAGE="$(kubectl -n starfleet-staging get deploy scout -o jsonpath='{.spec.template.spec.containers[0].image}')"
[[ "$IMAGE" == ghcr.io/stefanprodan/podinfo:6.15.0 ]] || fail "wrong scout image"
REPLICAS="$(kubectl -n starfleet-staging get deploy scout -o jsonpath='{.spec.replicas}')"
READY="$(kubectl -n starfleet-staging get deploy scout -o jsonpath='{.status.readyReplicas}')"
[[ "$REPLICAS" == 1 && "$READY" == 1 ]] || fail "need one ready scout replica"
CONFIGMAP="$(kubectl -n starfleet-staging get deploy scout -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}')"
[[ "$CONFIGMAP" == scout-settings-?* ]] || fail "use the generated scout-settings ConfigMap with its hash suffix"
MESSAGE="$(kubectl -n starfleet-staging get cm "$CONFIGMAP" -o jsonpath='{.data.PODINFO_UI_MESSAGE}')" || fail "no referenced ConfigMap"
[[ "$MESSAGE" == overlay-staging ]] || fail "wrong generated message"
kubectl diff -k "$OVERLAY" >/dev/null || fail "saved overlay differs from live state or cannot be rendered"
# Right after a rollout or rollback the Service can still send a request to a
# terminating pod, so poll until the response matches or the attempts run out.
BODY=""
for attempt in $(seq 1 10); do
  BODY="$(kubectl -n starfleet exec deploy/shuttle -- curl -fsS --max-time 10 http://scout.starfleet-staging/ 2>/dev/null)" || BODY=""
  if grep -Eq '"version": *"6.15.0"' <<<"$BODY" && grep -Eq '"message": *"overlay-staging"' <<<"$BODY"; then break; fi
  [[ "$attempt" -lt 10 ]] && sleep 2
done
[[ -n "$BODY" ]] || fail "request failed"
grep -Eq '"version": *"6.15.0"' <<<"$BODY" || fail "wrong response version"
grep -Eq '"message": *"overlay-staging"' <<<"$BODY" || fail "wrong response message"
echo "PASS: overlay"
