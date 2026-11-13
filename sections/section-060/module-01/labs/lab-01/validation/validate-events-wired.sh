#!/usr/bin/env bash
# Grades the Argo Events objects by their running pods and their filter.
set -u

fail() { echo "FAIL: $*"; exit 1; }
events() { kubectl -n argo-events get "$@" 2>/dev/null; }

events eventsource push-webhook >/dev/null || fail "no EventSource push-webhook in argo-events"
events sensor push-ci >/dev/null || fail "no Sensor push-ci in argo-events"

endpoint=$(events eventsource push-webhook -o jsonpath='{.spec.webhook.push.endpoint}')
port=$(events eventsource push-webhook -o jsonpath='{.spec.webhook.push.port}')
[[ "$endpoint" == "/push" && "$port" == "12000" ]] \
  || fail "the webhook event 'push' must listen on port 12000 at /push (found port '$port', endpoint '$endpoint')"
events svc push-webhook-eventsource-svc >/dev/null \
  || fail "no Service push-webhook-eventsource-svc; the EventSource needs spec.service.ports for port 12000"

es_pods=$(events pods -l eventsource-name=push-webhook --field-selector=status.phase=Running -o name | wc -l)
sensor_pods=$(events pods -l sensor-name=push-ci --field-selector=status.phase=Running -o name | wc -l)
[[ "$es_pods" -ge 1 ]] || fail "the EventSource pod is not Running"
[[ "$sensor_pods" -ge 1 ]] || fail "the Sensor pod is not Running"

filter_path=$(events sensor push-ci -o jsonpath='{.spec.dependencies[0].filters.data[0].path}')
filter_value=$(events sensor push-ci -o jsonpath='{.spec.dependencies[0].filters.data[0].value[*]}')
[[ "$filter_path" == "body.ref" && "$filter_value" == "refs/heads/main" ]] \
  || fail "the Sensor must filter body.ref for refs/heads/main (found path '$filter_path', value '$filter_value')"

template=$(events sensor push-ci -o jsonpath='{.spec.triggers[0].template.argoWorkflow.source.resource.spec.workflowTemplateRef.name}')
[[ "$template" == "run-tests" ]] || fail "the Sensor trigger must create a Workflow from the WorkflowTemplate run-tests (found '$template')"

echo "PASS: push-webhook and push-ci run, the Sensor filters refs/heads/main and starts run-tests"
