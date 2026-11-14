#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
EVENT_FILE=/tmp/scout-waiting-events.txt
[[ -s "$EVENT_FILE" ]] || fail "save events while Waiting to $EVENT_FILE"
CANARY_UID="$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')"
LIVE_EVENTS="$(kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" \
  -o go-template='{{range .items}}{{.metadata.uid}}{{"\t"}}{{.involvedObject.uid}}{{"\t"}}{{printf "%q" .message}}{{"\n"}}{{end}}')"
# New events arrive after approval. Every saved row must still exist, but the
# saved snapshot must not be replaced by the larger post-promotion event list.
while IFS= read -r EVENT_ROW; do
  [[ -n "$EVENT_ROW" ]] || fail 'saved events contain an empty row'
  grep -Fxq -- "$EVENT_ROW" <<<"$LIVE_EVENTS" || fail 'saved event identity, Canary identity or message differs from live events'
done < "$EVENT_FILE"
grep -Fq 'Halt scout.starfleet advancement waiting for approval scout-approval' "$EVENT_FILE" || fail 'save the waiting-for-approval event'
! grep -Eq 'Confirm-rollout check scout-approval passed|Promotion completed' "$EVENT_FILE" || fail 'save before opening the gate, not after promotion'
echo 'PASS: waiting-events'
