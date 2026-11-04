#!/usr/bin/env bash
# Grades the Pipeline definition: label-namespace runs in parallel with report-namespace.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }
read_pipeline() { kubectl -n "$NS" get pipelines.tekton.dev outpost-onboard -o jsonpath="$1" 2>/dev/null; }

entry=$(read_pipeline '{.spec.tasks[?(@.name=="label-namespace")].name}')
[[ "$entry" == "label-namespace" ]] || fail "the Pipeline outpost-onboard has no task named label-namespace"

task=$(read_pipeline '{.spec.tasks[?(@.name=="label-namespace")].taskRef.name}')
[[ "$task" == "label-namespace" ]] || fail "the task label-namespace must reference the Task label-namespace"

report=$(read_pipeline '{.spec.tasks[?(@.name=="report-namespace")].runAfter[*]}')
label=$(read_pipeline '{.spec.tasks[?(@.name=="label-namespace")].runAfter[*]}')
[[ "$report" == "create-namespace" ]] || fail "report-namespace must still wait only for create-namespace; it waits for '$report'"
[[ "$label" == "$report" ]] || fail "label-namespace must start at the same time as report-namespace; it waits for '$label'"

namespace=$(read_pipeline '{.spec.tasks[?(@.name=="label-namespace")].params[?(@.name=="namespace")].value}')
[[ "$namespace" == '$(tasks.plan-namespace.results.namespace)' ]] || fail "the param namespace of label-namespace must come from the result of an earlier Task"

tier_param=$(read_pipeline '{.spec.params[?(@.name=="tier")].name}')
[[ "$tier_param" == "tier" ]] || fail "the Pipeline has no param named tier"
tier=$(read_pipeline '{.spec.tasks[?(@.name=="label-namespace")].params[?(@.name=="tier")].value}')
[[ "$tier" == '$(params.tier)' ]] || fail "the param tier of label-namespace must come from the Pipeline param tier"

echo "PASS: label-namespace runs in parallel with report-namespace and receives both values"
