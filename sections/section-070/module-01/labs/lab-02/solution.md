# Solution Walkthrough

You will finish a paused release by hand, then make the next release pass an automatic check. A Rollout is the Argo Rollouts resource that manages a release. An AnalysisTemplate defines a check, and an AnalysisRun is the object that holds the result of one check.

| Goal | Object or file | Field |
| --- | --- | --- |
| Finish the paused release | Rollout `scout` | `promote`, then `promote --full` |
| Check the canary | AnalysisTemplate `scout-canary-message` | `provider.web.url`, `provider.web.jsonPath`, `successCondition` |
| Check the release automatically | Rollout `scout` | `spec.strategy.canary.steps[1].analysis` |
| Start a release | Rollout `scout` | `PODINFO_UI_MESSAGE` in the pod template |
| Keep the result | `/tmp/scout-analysisrun.txt` | AnalysisRun name, phase and first measurement value |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-070/module-01/labs/lab-02
```

The four checks are `full-promotion`, `web-analysis-step`, `gated-release` and `saved-analysisrun`. None passes in the untouched environment. Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Finish the paused release

Read the starting state, then promote once:

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl argo rollouts promote scout -n starfleet
kubectl -n starfleet wait rollout/scout --for=jsonpath='{.status.currentStepIndex}'=3 --timeout=180s
```

Look for status `Paused` and step `1/4` before you promote. A normal promotion clears that pause. The controller then runs `setWeight: 60` and stops at the second pause, step `3/4`.

Finish the release with a full promotion, which skips the remaining steps:

```sh
kubectl argo rollouts promote scout -n starfleet --full
kubectl argo rollouts status scout -n starfleet --timeout 180s
```

Look for `Healthy`. The `full-promotion` check should now pass.

## Complete the AnalysisTemplate

Read the unfinished template first:

```sh
kubectl -n starfleet get analysistemplate scout-canary-message -o yaml
```

It requests the `scout` Service, which selects the stable pods too. It also has no `jsonPath` or `successCondition`.

Save this as `analysistemplate-scout-canary-message.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: scout-canary-message
  namespace: starfleet
spec:
  metrics:
    - name: message
      initialDelay: 15s
      count: 3
      interval: 10s
      successCondition: result == "canary-ready"
      provider:
        web:
          url: http://scout-canary.starfleet/
          timeoutSeconds: 5
          jsonPath: "{$.message}"
```

`url` requests the Service that selects only the canary pods. `jsonPath` sits under `web` and selects the `message` field of the response. Its value becomes `result` in `successCondition`, which sits on the metric.

Apply it:

```sh
kubectl apply -f analysistemplate-scout-canary-message.yaml
```

## Replace the first pause

Index 1 of the steps list is the first pause. Replace only that step:

```sh
kubectl -n starfleet patch rollout scout --type=json -p='[{"op":"replace","path":"/spec/strategy/canary/steps/1","value":{"analysis":{"templates":[{"templateName":"scout-canary-message"}]}}}]'
kubectl -n starfleet get rollout scout -o jsonpath='{.spec.strategy.canary.steps}{"\n"}'
```

Look for four steps with `analysis` in the second place. The Rollout stays `Healthy`, because a change to the steps alone starts no release on a stable template. The `web-analysis-step` check should now pass.

## Trigger the release

An environment variable is part of the pod template, so changing it starts a release:

```sh
kubectl -n starfleet patch rollout scout --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/env","value":[{"name":"PODINFO_UI_MESSAGE","value":"canary-ready"}]}]'
kubectl -n starfleet wait rollout/scout --for=jsonpath='{.status.currentStepIndex}'=3 --timeout=180s
kubectl argo rollouts get rollout scout -n starfleet --no-color
```

Wait without promoting. A promotion during the analysis step would cancel the check. Look for status `Paused` and step `3/4`, which show that the check passed.

## Read the AnalysisRun

Find the run by the pod hash of this release, then save its details:

```sh
HASH=$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.currentPodHash}')
RUN_NAME=$(kubectl -n starfleet get analysisrun -l "rollout-type=Step,rollouts-pod-template-hash=$HASH" -o jsonpath='{.items[?(@.status.phase=="Successful")].metadata.name}')
kubectl -n starfleet get analysisrun "$RUN_NAME" -o jsonpath='{.metadata.name} {.status.phase} {.status.metricResults[0].measurements[0].value}{"\n"}' > /tmp/scout-analysisrun.txt
cat /tmp/scout-analysisrun.txt
```

Look for phase `Successful` and the value `"canary-ready"`. The double quotes are part of the stored value. The `saved-analysisrun` check should now pass.

## Finish the release

Use a normal promotion, because only the last pause remains:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl argo rollouts status scout -n starfleet --timeout 180s
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet/
```

Look for `Healthy`, version `6.15.0` and message `canary-ready`. Old pods can answer for a few seconds after `Healthy`, so repeat the request if needed. All four checks should now pass. Stop the watch with Ctrl-C and submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-070/module-01/labs/lab-02
```

## If a check stays red

- **`full-promotion`:** The paused release must reach step `3/4` before `promote --full`. If you skipped that stop, the grader cannot record it for that release, so destroy the lab and start again.
- **`web-analysis-step`:** Read the template and steps with `kubectl get -o yaml`. Keep `jsonPath` under `provider.web` and `successCondition` on the metric. Keep the other three steps unchanged.
- **`gated-release`:** Read the AnalysisRun if the Rollout is `Degraded`. Fix the cause, then change the message value to start a new release. If you used `--full` on this release, change the pod template again and use a normal promotion.
- **`saved-analysisrun`:** Save the line again after the last release. Keep the quotes in the value and use single spaces. A later release makes the saved run out of date.
