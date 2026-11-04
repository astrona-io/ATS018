#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
EVENT_FILE=/tmp/scout-canary-events.txt
[[ -s "$EVENT_FILE" ]] || fail "save Canary events to $EVENT_FILE"
CANARY_UID="$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')" || fail 'create the scout Canary'
LIVE_EVENTS="$(kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" \
  -o go-template='{{range .items}}{{.metadata.uid}}{{"\t"}}{{.involvedObject.uid}}{{"\t"}}{{printf "%q" .message}}{{"\n"}}{{end}}')"
diff -u <(printf '%s\n' "$LIVE_EVENTS" | sort) <(sort "$EVENT_FILE") || fail 'saved event identities and messages must match live Canary events; save again after promotion'
grep -q 'pre-rollout check scout-http-check failed' "$EVENT_FILE" || fail 'save the failure events'
grep -q 'Promotion completed' "$EVENT_FILE" || fail 'save after the successful promotion'
echo 'PASS: saved-events'
