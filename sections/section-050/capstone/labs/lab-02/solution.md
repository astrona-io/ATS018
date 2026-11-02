# Solution

## Step 1: read why the Rollout is Degraded

Read the status of the Rollout:

```sh
kubectl argo rollouts get rollout scout -n starfleet
```

```text
Status:          ✖ Degraded
Message:         InvalidSpec: The Rollout "scout" is invalid: spec.strategy.trafficRouting.managedRoutes: Required value: Rollout has missing field 'spec.strategy.canary.trafficRouting.managedRoutes'
```

The step `setHeaderRoute` creates a rule in the `HTTPRoute`. The Rollout must list the name of every such rule in `managedRoutes`, so the controller knows which rules it owns and may remove. The Rollout is `Degraded` and starts no release until the field exists. Add it:

```sh
kubectl -n starfleet patch rollout scout --type=json \
  -p '[{"op":"add","path":"/spec/strategy/canary/trafficRouting/managedRoutes","value":[{"name":"canary-header"}]}]'
kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}{"\n"}'
```

The phase is `Healthy` again.

## Step 2: release the good canary and read the second symptom

Change the message in the pod template. This starts a release:

```sh
kubectl -n starfleet patch rollout scout --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"good-build"}]'
```

After about 30 seconds the Rollout is `Paused` at step 1 of 6 with `CanaryPauseStep`. The new ReplicaSet is `ScaledDown`: it has no pods. The step list has no `setCanaryScale`, and at weight 0 the controller starts no canary pods. Read the `HTTPRoute` rules:

```sh
kubectl -n starfleet get httproute scout-route -o jsonpath='{range .spec.rules[*]}{.name}{" "}{range .backendRefs[*]}{.name}={.weight} {end}{"\n"}{end}'
```

```text
 scout=100 scout-canary=0 
```

There is one rule and no `canary-header` rule, so a header request cannot reach the canary. The controller log of `argo-rollouts` shows `RemoveManagedRoutes` right after `SetHeaderRoute`: while the canary Service has no pods, the controller removes the header rule again. Put a `setCanaryScale` step first, so one canary pod runs while testers use the header route:

```sh
kubectl -n starfleet patch rollout scout --type=json \
  -p '[{"op":"add","path":"/spec/strategy/canary/steps/0","value":{"setCanaryScale":{"replicas":1}}}]'
```

Wait about 45 seconds. A changed step list restarts the steps, and the canary pod starts. The Rollout is `Paused` at step 2 of 7, and the route now has the rule:

```sh
kubectl -n starfleet get httproute scout-route -o jsonpath='{range .spec.rules[*]}{.name}{" "}{.matches[*].headers[*].name}{"="}{.matches[*].headers[*].value}{" "}{range .backendRefs[*]}{.name}={.weight} {end}{"\n"}{end}'
```

```text
 = scout=100 scout-canary=0 
canary-header x-canary=Yes scout-canary=1 
```

## Step 3: fix the header value

The rule matches `Yes`, but testers send `yes`. A header match with `exact` is case-sensitive. Send both from `shuttle` and compare:

```sh
GATEWAY_ADDRESS=$(kubectl -n starfleet get deploy shuttle -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GATEWAY")].value}')
for value in yes Yes; do
  echo "x-canary: $value"
  kubectl -n starfleet exec deploy/shuttle -- curl -s -H "x-canary: $value" http://$GATEWAY_ADDRESS/ | grep message
done
```

```text
x-canary: yes
  "message": "stable",
x-canary: Yes
  "message": "good-build",
```

Change the value in the Rollout to `yes`:

```sh
kubectl -n starfleet patch rollout scout --type=json \
  -p '[{"op":"replace","path":"/spec/strategy/canary/steps/1/setHeaderRoute/match/0/headerValue/exact","value":"yes"}]'
```

Wait about 20 seconds, then run the loop again. Now `yes` returns `good-build` and `Yes` returns `stable`.

## Step 4: promote and read the failed analysis

The header test passed, so promote the canary to the weight steps:

```sh
kubectl argo rollouts promote scout -n starfleet
```

The Rollout sets weight 20 and starts the background analysis at step 4. After about two and a half minutes, list the AnalysisRuns:

```sh
kubectl -n starfleet get analysisrun
kubectl -n starfleet get rollout scout -o jsonpath='{.status.message}{"\n"}'
```

```text
NAME                 STATUS   AGE
scout-847794f886-2   Failed   2m30s
RolloutAborted: Rollout aborted update to revision 2: Background analysis phase error/failed: Metric "success-rate" assessed Failed due to failed (2) > failureLimit (1)
```

The good canary failed its own analysis, and the Rollout aborted. The measurements in the `AnalysisRun` are empty (`[]`). Read the query:

```sh
kubectl -n starfleet get analysistemplate scout-success -o jsonpath='{.spec.metrics[0].provider.prometheus.query}'
```

The numerator counts `status=~"5.."`, the 5xx responses. A good build has none, so the query returns nothing and the failure condition `len(result) != 1` is true. The query must count 2xx responses.

## Step 5: fix the query and retry

Replace the status matcher, then retry the aborted release:

```sh
kubectl -n starfleet patch analysistemplate scout-success --type=json -p '[{"op":"replace","path":"/spec/metrics/0/provider/prometheus/query","value":"sum(rate(http_request_duration_seconds_count{namespace=\"starfleet\",path=\"root\",rollouts_pod_template_hash=\"{{args.canary-hash}}\",status=~\"2..\"}[1m]))\n/\nsum(rate(http_request_duration_seconds_count{namespace=\"starfleet\",path=\"root\",rollouts_pod_template_hash=\"{{args.canary-hash}}\"}[1m]))\n"}]'
kubectl argo rollouts retry rollout scout -n starfleet
```

Wait until the Rollout is `Paused` at step 2 again, promote it and wait until it is `Healthy`:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl argo rollouts get rollout scout -n starfleet --watch
```

Press `Ctrl+C` when the status is `Healthy`. List the AnalysisRuns:

```sh
kubectl -n starfleet get analysisrun -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{" "}{.status.metricResults[0].measurements[*].value}{"\n"}{end}'
```

```text
scout-847794f886-2 Failed [] []
scout-847794f886-2.1 Successful [1] [1] [1] [1] [1] [1]
```

The retry created a second AnalysisRun. It measured a 2xx share of 1 and succeeded.

## Step 6: release the faulty canary

Change the message and add `--random-error` to the command:

```sh
kubectl -n starfleet patch rollout scout --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"bad-build"},{"op":"add","path":"/spec/template/spec/containers/0/command/-","value":"--random-error"}]'
```

Wait until the Rollout is `Paused` at step 2 and promote it:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl argo rollouts get rollout scout -n starfleet --watch
```

After about two minutes the Rollout is `Degraded` with `RolloutAborted`. The new AnalysisRun is `Failed` with measurements below 0.99:

```sh
kubectl -n starfleet get analysisrun -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{" "}{.status.metricResults[0].measurements[*].value}{"\n"}{end}'
```

```text
scout-5bbb6b4c4d-3 Failed [0.7007693934349503] [0.6815685513784724]
scout-847794f886-2 Failed [] []
scout-847794f886-2.1 Successful [1] [1] [1] [1] [1] [1]
```

The stable pods kept serving `good-build` while the faulty canary ran.

## Step 7: restore the template and submit

Set the message back to `good-build` and remove `--random-error`:

```sh
kubectl -n starfleet patch rollout scout --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"good-build"},{"op":"remove","path":"/spec/template/spec/containers/0/command/3"}]'
kubectl -n starfleet get rollout scout -o jsonpath='{.status.phase}{"\n"}'
```

The template is the stable one again, so the Rollout is `Healthy` at once and no new release starts. Then submit:

```sh
astrona submit
```

The first check reads the managed route and the first steps of the Rollout. The second reads the AnalysisTemplate query and the analysis argument. The third reads the AnalysisRun history (one `Successful` run with a measurement of 0.99 or higher, one `Failed` run with a measurement below 0.99), the final template, the `HTTPRoute` and real requests from `shuttle`.
