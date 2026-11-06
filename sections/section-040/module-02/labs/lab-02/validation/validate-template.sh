#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: template — $*"; exit 1; }
run_fields=$(kubectl -n starfleet get triggertemplate scout-check -o jsonpath='{.spec.resourcetemplates[0].apiVersion}|{.spec.resourcetemplates[0].kind}|{.spec.resourcetemplates[0].metadata.generateName}|{.spec.resourcetemplates[0].spec.pipelineRef.name}|{.spec.resourcetemplates[0].spec.taskRunTemplate.serviceAccountName}') || fail 'create TriggerTemplate scout-check'
[[ "$run_fields" == 'tekton.dev/v1|PipelineRun|scout-check-|scout-check|scout-runner' ]] || fail 'use tekton.dev/v1 PipelineRun, generateName scout-check-, Pipeline scout-check and scout-runner'
for param in revision repository; do
  declared=$(kubectl -n starfleet get triggertemplate scout-check -o "jsonpath={.spec.params[?(@.name==\"$param\")].name}")
  value=$(kubectl -n starfleet get triggertemplate scout-check -o "jsonpath={.spec.resourcetemplates[0].spec.params[?(@.name==\"$param\")].value}")
  [[ "$declared" == "$param" && "$value" == '$(tt.params.'"$param"')' ]] || fail "declare and substitute $param"
done
original_spec=$(kubectl -n starfleet get configmap scout-check-start -o jsonpath='{.data.spec}') || fail 'the bootstrap Pipeline snapshot is missing'
current_spec=$(kubectl -n starfleet get pipeline scout-check -o jsonpath='{.spec}') || fail 'keep the existing Pipeline scout-check'
[[ -n "$original_spec" && "$current_spec" == "$original_spec" ]] || fail 'keep Pipeline scout-check unchanged'
echo 'PASS: template'
