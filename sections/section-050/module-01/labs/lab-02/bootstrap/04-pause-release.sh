#!/usr/bin/env bash
# Start the 6.15.0 release and wait until it stops at the first pause (step index 1).
# Record its pod hash so the grader knows which release this was.
set -euo pipefail

kubectl -n starfleet patch rollout scout --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"ghcr.io/stefanprodan/podinfo:6.15.0"}]'

for attempt in $(seq 1 60); do
  state="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.currentStepIndex}/{.status.pauseConditions[0].reason}' 2>/dev/null || true)"
  if [ "$state" = "1/CanaryPauseStep" ]; then
    hash="$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.currentPodHash}')"
    kubectl -n starfleet patch configmap release-trace --type=merge \
      -p "{\"data\":{\"firstReleaseHash\":\"$hash\"}}"
    exit 0
  fi
  sleep 5
done
echo "scout did not reach the first pause within 300 seconds" >&2
exit 1
