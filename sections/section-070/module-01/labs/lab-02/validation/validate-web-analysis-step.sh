#!/usr/bin/env bash
# Grades tasks 2 and 3: the finished web metric and the inline analysis step.
set -u

NS="starfleet"
TEMPLATE="scout-canary-message"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n "$NS" get analysistemplate "$TEMPLATE" >/dev/null 2>&1 || fail "the AnalysisTemplate $TEMPLATE is missing"

metric_name=$(kubectl -n "$NS" get analysistemplate "$TEMPLATE" -o jsonpath='{.spec.metrics[0].name}')
[[ "$metric_name" == "message" ]] || fail "the metric name changed; keep the name message"

url=$(kubectl -n "$NS" get analysistemplate "$TEMPLATE" -o jsonpath='{.spec.metrics[0].provider.web.url}')
[[ "$url" == "http://scout-canary.starfleet/" ]] || fail "the web metric does not request the address the task names"

json_path=$(kubectl -n "$NS" get analysistemplate "$TEMPLATE" -o jsonpath='{.spec.metrics[0].provider.web.jsonPath}')
[[ "$json_path" == '{$.message}' || "$json_path" == '{.message}' ]] || fail "web.jsonPath does not read the message field of the response"

condition=$(kubectl -n "$NS" get analysistemplate "$TEMPLATE" -o jsonpath='{.spec.metrics[0].successCondition}')
grep -Eq "^ *(result *== *[\"']canary-ready[\"']|[\"']canary-ready[\"'] *== *result) *$" <<<"$condition" \
  || fail "successCondition on the metric must compare result with the value the task names"

canary_service=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.canaryService}')
[[ "$canary_service" == "scout-canary" ]] || fail "keep canaryService in the Rollout strategy; without it the Service selects both versions"

step_marks=$(kubectl -n "$NS" get rollout scout -o jsonpath='{range .spec.strategy.canary.steps[*]}x{end}')
[[ "${#step_marks}" -eq 4 ]] || fail "the Rollout must have exactly 4 canary steps, it has ${#step_marks}"

first_weight=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[0].setWeight}')
[[ "$first_weight" == "20" ]] || fail "the first step must stay setWeight 20"

second_pause=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[1].pause}')
[[ -z "$second_pause" ]] || fail "step 1 is still a pause; replace it with an inline analysis step"

step_template=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[1].analysis.templates[0].templateName}')
[[ "$step_template" == "$TEMPLATE" ]] || fail "step 1 must be an analysis step that uses $TEMPLATE"

third_weight=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[2].setWeight}')
[[ "$third_weight" == "60" ]] || fail "step 2 must stay setWeight 60"

last_step=$(kubectl -n "$NS" get rollout scout -o jsonpath='{.spec.strategy.canary.steps[3]}')
[[ "$last_step" == *pause* ]] || fail "step 3 must stay a pause"

echo "PASS: the template checks the canary Service and an inline analysis step replaced the first pause"
