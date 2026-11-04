#!/usr/bin/env bash
# Grades the RBAC fix: outpost-provisioner has what the Tasks need, and no account has too much.
set -u

ACCOUNT="system:serviceaccount:starfleet:outpost-provisioner"
fail() { echo "FAIL: $*"; exit 1; }
can() { kubectl auth can-i "$@" --quiet >/dev/null 2>&1; }

for verb in get create patch; do
  can "$verb" namespaces --as="$ACCOUNT" || fail "outpost-provisioner cannot yet do everything the Tasks of outpost-onboard need on namespaces"
done

can delete namespaces --as="$ACCOUNT" && fail "outpost-provisioner has more rights on namespaces than the Tasks need"
can get secrets --all-namespaces --as="$ACCOUNT" && fail "outpost-provisioner has rights outside namespaces that the Tasks do not need"
can create namespaces --as="system:serviceaccount:starfleet:default" && fail "the ServiceAccount default in starfleet must have no rights on namespaces"

echo "PASS: outpost-provisioner has the rights the Tasks need and no more"
