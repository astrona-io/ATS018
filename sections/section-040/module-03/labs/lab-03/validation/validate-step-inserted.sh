#!/usr/bin/env bash
# Grades the template change: main runs four groups in order, verify-checksum sits between
# fetch-manifest and deploy, gets the manifest from fetch-manifest, and its template hashes it.
set -uo pipefail

NS="starfleet"
TEMPLATE="shuttle-release"
fail() { echo "FAIL: step-inserted: $*"; exit 1; }
field() { kubectl -n "$NS" get workflowtemplate "$TEMPLATE" -o jsonpath="$1" 2>/dev/null; }

kubectl -n "$NS" get workflowtemplate "$TEMPLATE" >/dev/null 2>&1 || fail "no WorkflowTemplate $TEMPLATE in $NS"
[[ "$(field '{.spec.entrypoint}')" == "main" ]] || fail "keep main as the entrypoint of $TEMPLATE"

# One line per step group: "name:template," for every step in the group.
groups=$(field '{range .spec.templates[?(@.name=="main")].steps[*]}{range @[*]}{.name}:{.template},{end}{"\n"}{end}')
[[ -n "$groups" ]] || fail "the template main of $TEMPLATE must keep its steps list"
group_count=$(printf '%s\n' "$groups" | wc -l | tr -d ' ')
[[ "$group_count" == "4" ]] || fail "the steps list of main must have four groups, one per step, not $group_count"

expected=("fetch-manifest:fetch-manifest," "verify-checksum:verify-checksum," "deploy:deploy," "notify:notify,")
for i in 0 1 2 3; do
  line=$(printf '%s\n' "$groups" | sed -n "$((i + 1))p")
  [[ "$line" == "${expected[$i]}" ]] \
    || fail "group $((i + 1)) of main must hold only the step ${expected[$i]%%:*} with the template ${expected[$i]%%:*}; it holds '$line'"
done

# The new step takes the manifest that fetch-manifest produced.
argument=$(field '{.spec.templates[?(@.name=="main")].steps[1][*].arguments.parameters[?(@.name=="manifest")].value}')
[[ "$argument" == *"steps.fetch-manifest.outputs.parameters.manifest"* ]] \
  || fail "the step verify-checksum must pass the parameter manifest with the value {{steps.fetch-manifest.outputs.parameters.manifest}}"

# The template verify-checksum: one input, a SHA-256 command and the checksum output.
[[ "$(field '{.spec.templates[?(@.name=="verify-checksum")].inputs.parameters[*].name}')" == *manifest* ]] \
  || fail "the template verify-checksum must declare the input parameter manifest"
command_text=$(field '{.spec.templates[?(@.name=="verify-checksum")].container.command[*]} {.spec.templates[?(@.name=="verify-checksum")].container.args[*]} {.spec.templates[?(@.name=="verify-checksum")].script.command[*]} {.spec.templates[?(@.name=="verify-checksum")].script.source}')
[[ "$command_text" == *sha256sum* ]] || fail "the template verify-checksum must compute the checksum with sha256sum"
[[ "$command_text" == *"inputs.parameters.manifest"* ]] || fail "the template verify-checksum must hash {{inputs.parameters.manifest}}"
[[ "$(field '{.spec.templates[?(@.name=="verify-checksum")].outputs.parameters[?(@.name=="checksum")].valueFrom.path}')" == /* ]] \
  || fail "the template verify-checksum must write the checksum to a file and export it as the output parameter checksum"

# The three existing templates stay as they were.
[[ "$(field '{.spec.templates[?(@.name=="fetch-manifest")].outputs.parameters[?(@.name=="manifest")].valueFrom.path}')" == "/tmp/manifest.txt" ]] \
  || fail "keep the template fetch-manifest and its output parameter manifest as they were"
[[ "$(field '{.spec.templates[?(@.name=="deploy")].container.args[*]}')" == *deploying* ]] \
  || fail "keep the template deploy as it was"
[[ "$(field '{.spec.templates[?(@.name=="notify")].container.command[*]}')" == *"release done"* ]] \
  || fail "keep the template notify as it was"
[[ "$(field '{.spec.templates[?(@.name=="main")].steps[2][*].arguments.parameters[?(@.name=="manifest")].value}')" == *"steps.fetch-manifest.outputs.parameters.manifest"* ]] \
  || fail "the step deploy must still get the manifest from fetch-manifest"

echo "PASS: step-inserted: verify-checksum runs between fetch-manifest and deploy"
