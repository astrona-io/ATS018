#!/usr/bin/env bash
# Grades the result: the checksum the new step exported is the SHA-256 of the manifest that
# fetch-manifest exported in the same run.
set -uo pipefail

NS="starfleet"
TEMPLATE="shuttle-release"
fail() { echo "FAIL: checksum-output: $*"; exit 1; }

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 | awk '{print $1}'; }
else
  fail "neither sha256sum nor shasum is on the PATH of the grading terminal"
fi

rows=$(kubectl -n "$NS" get workflows -o jsonpath='{range .items[*]}{.metadata.name}|{.spec.workflowTemplateRef.name}|{.status.phase}{"\n"}{end}' 2>/dev/null)
names=$(printf '%s\n' "$rows" | awk -F'|' -v t="$TEMPLATE" '$2 == t && $3 == "Succeeded" {print $1}')
[[ -n "$names" ]] || fail "no Succeeded Workflow from the WorkflowTemplate $TEMPLATE in $NS"

seen_step=false
for name in $names; do
  manifest=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{.status.nodes[?(@.displayName=="fetch-manifest")].outputs.parameters[?(@.name=="manifest")].value}' 2>/dev/null)
  checksum=$(kubectl -n "$NS" get workflow "$name" -o jsonpath='{.status.nodes[?(@.displayName=="verify-checksum")].outputs.parameters[?(@.name=="checksum")].value}' 2>/dev/null | tr -d '[:space:]')
  [[ -n "$checksum" ]] || continue
  seen_step=true
  [[ -n "$manifest" ]] || fail "the run $name has no output parameter manifest on fetch-manifest; keep that template as it was"
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail "the output parameter checksum of verify-checksum in $name is '$checksum', not a 64-character SHA-256 hex digest"
  expected=$(printf '%s' "$manifest" | sha256)
  [[ "$checksum" == "$expected" ]] && { echo "PASS: checksum-output: $name exported the SHA-256 of the manifest"; exit 0; }
  fail "the checksum in $name is $checksum, but the SHA-256 of the manifest '$manifest' is $expected; hash exactly the value of the parameter"
done

[[ "$seen_step" == true ]] || fail "no Succeeded run of $TEMPLATE exported the output parameter checksum from verify-checksum"
fail "no run matched"
