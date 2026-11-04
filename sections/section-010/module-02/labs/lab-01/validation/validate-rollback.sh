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
echo "PASS: rollback"
