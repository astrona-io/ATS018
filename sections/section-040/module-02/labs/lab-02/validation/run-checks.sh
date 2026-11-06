#!/usr/bin/env bash
# Check the live PipelineRun and its TaskRun, including actual parameter delivery.
run_matches() {
  local run_name="$1" revision="$2" repository="$3" fields task_name task_fields
  fields=$(kubectl -n starfleet get pipelinerun "$run_name" -o jsonpath='{.spec.pipelineRef.name}|{.spec.taskRunTemplate.serviceAccountName}|{.spec.params[?(@.name=="revision")].value}|{.spec.params[?(@.name=="repository")].value}|{.status.conditions[?(@.type=="Succeeded")].status}') || return 1
  [[ "$fields" == "scout-check|scout-runner|$revision|$repository|True" ]] || return 1
  task_name=$(kubectl -n starfleet get taskruns -l "tekton.dev/pipelineRun=$run_name,tekton.dev/pipelineTask=check-payload" -o jsonpath='{.items[0].metadata.name}') || return 1
  [[ -n "$task_name" ]] || return 1
  task_fields=$(kubectl -n starfleet get taskrun "$task_name" -o jsonpath='{.spec.serviceAccountName}|{.spec.params[?(@.name=="revision")].value}|{.spec.params[?(@.name=="repository")].value}|{.status.conditions[?(@.type=="Succeeded")].status}') || return 1
  [[ "$task_fields" == "scout-runner|$revision|$repository|True" ]]
}
