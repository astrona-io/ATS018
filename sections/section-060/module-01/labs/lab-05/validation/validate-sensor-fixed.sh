#!/usr/bin/env bash
# The Sensor must be repaired, not replaced by one that skips the filter or the commit ID.
set -u

fail() { echo "FAIL: $*"; exit 1; }
events() { kubectl -n argo-events get "$@" 2>/dev/null; }

events eventsource push-webhook >/dev/null || fail "no EventSource push-webhook in argo-events"
events sensor push-ci >/dev/null || fail "no Sensor push-ci in argo-events"

sa=$(events sensor push-ci -o jsonpath='{.spec.template.serviceAccountName}')
[[ "$sa" == "workflow-submitter" ]] || fail "the Sensor must run as workflow-submitter (found '$sa')"

filter_path=$(events sensor push-ci -o jsonpath='{.spec.dependencies[0].filters.data[0].path}')
filter_value=$(events sensor push-ci -o jsonpath='{.spec.dependencies[0].filters.data[0].value[*]}')
[[ "$filter_path" == "body.ref" && "$filter_value" == "refs/heads/main" ]] \
  || fail "the Sensor must filter body.ref for refs/heads/main (found path '$filter_path', value '$filter_value')"

template=$(events sensor push-ci -o jsonpath='{.spec.triggers[0].template.argoWorkflow.source.resource.spec.workflowTemplateRef.name}')
[[ "$template" == "run-tests" ]] || fail "the Sensor trigger must create a Workflow from the WorkflowTemplate run-tests (found '$template')"

datakey=$(events sensor push-ci -o jsonpath='{.spec.triggers[0].template.argoWorkflow.parameters[0].src.dataKey}')
dest=$(events sensor push-ci -o jsonpath='{.spec.triggers[0].template.argoWorkflow.parameters[0].dest}')
[[ "$datakey" == "body.after" ]] \
  || fail "the trigger must pass the pushed commit body.after as the revision (found dataKey '$datakey')"
[[ "$dest" == "spec.arguments.parameters.0.value" ]] \
  || fail "the trigger must write the commit ID into the first Workflow argument (found dest '$dest')"

es_pods=$(events pods -l eventsource-name=push-webhook --field-selector=status.phase=Running -o name | wc -l)
sensor_pods=$(events pods -l sensor-name=push-ci --field-selector=status.phase=Running -o name | wc -l)
[[ "$es_pods" -ge 1 ]] || fail "the EventSource pod is not Running"
[[ "$sensor_pods" -ge 1 ]] || fail "the Sensor pod is not Running"

echo "PASS: push-ci filters refs/heads/main, passes body.after as the revision and runs"
