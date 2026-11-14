#!/usr/bin/env bash
# Grades the two runs: each site has a Succeeded run with its own values, the right
# account and the parallel Task, and that run wrote the labels on its namespace.
set -u

NS="starfleet"
ACCOUNT="outpost-provisioner"
fail() { echo "FAIL: $*"; exit 1; }

rows=$(kubectl -n "$NS" get pipelineruns.tekton.dev -o jsonpath='{range .items[?(@.spec.pipelineRef.name=="outpost-onboard")]}{.metadata.name}{"|"}{.status.conditions[0].status}{"|"}{.spec.params[?(@.name=="site")].value}{"|"}{.spec.params[?(@.name=="tier")].value}{"\n"}{end}' 2>/dev/null)

run_is_good() {
  local name="$1" namespace="$2" tier="$3" accounts report label taskrun status value labels
  accounts=$(kubectl -n "$NS" get taskruns.tekton.dev -l "tekton.dev/pipelineRun=$name" -o jsonpath='{range .items[*]}{.spec.serviceAccountName}{"\n"}{end}' 2>/dev/null)
  if [[ -z "$accounts" ]] || printf '%s\n' "$accounts" | grep -qvx "$ACCOUNT"; then
    reason="the TaskRuns of $name did not all run as $ACCOUNT"
    return 1
  fi

  report=$(kubectl -n "$NS" get pipelineruns.tekton.dev "$name" -o jsonpath='{.status.pipelineSpec.tasks[?(@.name=="report-namespace")].runAfter[*]}' 2>/dev/null)
  label=$(kubectl -n "$NS" get pipelineruns.tekton.dev "$name" -o jsonpath='{.status.pipelineSpec.tasks[?(@.name=="label-namespace")].runAfter[*]}' 2>/dev/null)
  if [[ "$report" != "create-namespace" || "$label" != "create-namespace" ]]; then
    reason="$name did not run label-namespace and report-namespace in parallel; start a new run after you change the Pipeline"
    return 1
  fi

  taskrun=$(kubectl -n "$NS" get taskruns.tekton.dev -l "tekton.dev/pipelineRun=$name,tekton.dev/pipelineTask=label-namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  status=$(kubectl -n "$NS" get taskruns.tekton.dev "$taskrun" -o jsonpath='{.status.conditions[0].status}' 2>/dev/null)
  value=$(kubectl -n "$NS" get taskruns.tekton.dev "$taskrun" -o jsonpath='{.spec.params[?(@.name=="namespace")].value}|{.spec.params[?(@.name=="tier")].value}' 2>/dev/null)
  if [[ "$status" != "True" || "$value" != "$namespace|$tier" ]]; then
    reason="the label-namespace TaskRun of $name did not succeed with namespace $namespace and tier $tier"
    return 1
  fi

  labels=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.tier}|{.metadata.labels.onboarded-by}' 2>/dev/null)
  if [[ "$labels" != "$tier|$taskrun" ]]; then
    reason="the namespace $namespace must carry the labels that $name wrote"
    return 1
  fi
  return 0
}

check_site() {
  local site="$1" tier="$2" namespace="outpost-$1" names name
  names=$(printf '%s\n' "$rows" | awk -F'|' -v site="$site" -v tier="$tier" '$2 == "True" && $3 == site && $4 == tier {print $1}')
  reason="no Succeeded PipelineRun of outpost-onboard with site=$site and tier=$tier"
  for name in $names; do
    if run_is_good "$name" "$namespace" "$tier"; then
      echo "$site: $name"
      return 0
    fi
  done
  fail "$reason"
}

check_site vega gold
check_site rigel silver

echo "PASS: each site has a Succeeded run with its own values, and that run labelled its namespace"
