#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: binding — $*"; exit 1; }
revision=$(kubectl -n starfleet get triggerbinding scout-push -o jsonpath='{.spec.params[?(@.name=="revision")].value}') || fail 'create TriggerBinding scout-push'
repository=$(kubectl -n starfleet get triggerbinding scout-push -o jsonpath='{.spec.params[?(@.name=="repository")].value}') || fail 'read repository param'
[[ "$revision" == '$(body.ref)' ]] || fail 'revision must read $(body.ref)'
[[ "$repository" == '$(body.repository.full_name)' ]] || fail 'repository must read $(body.repository.full_name)'
echo 'PASS: binding'
