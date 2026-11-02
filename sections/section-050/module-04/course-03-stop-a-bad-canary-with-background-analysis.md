# Stop A Bad Canary With Background Analysis

A header route lets you test a canary by hand, but nobody watches a release all day. Argo Rollouts can check the canary's metrics for you. A background analysis is an analysis that starts at a chosen step and runs in the background while the later steps continue. If a metric fails, the controller aborts the release and sends all traffic back to the stable version. This part adds a background analysis to the Rollout and proves it with a good release and a faulty one.

## The AnalysisTemplate

An `AnalysisTemplate` is the Argo Rollouts object that holds metric queries and the conditions that decide whether each measurement passes. This template asks Prometheus for the share of successful responses (status codes 200 to 299) that the canary pods returned in the last minute. A measurement passes when the share is at least 0.99. The query selects the canary pods by the label `rollouts_pod_template_hash`, which a PodMonitor in the playground copies from the pod label. The template takes the hash as an argument.

Save this as `analysistemplate-scout-success.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: scout-success
  namespace: starfleet
spec:
  args:
    - name: canary-hash
  metrics:
    - name: success-rate
      initialDelay: 45s
      interval: 15s
      failureLimit: 1
      successCondition: len(result) == 1 && result[0] >= 0.99
      failureCondition: len(result) != 1 || result[0] < 0.99
      provider:
        prometheus:
          address: http://kps-prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.canary-hash}}",status=~"2.."}[1m]))
            /
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.canary-hash}}"}[1m]))
```

The metric has no `count` field. It measures every 15 seconds until the analysis ends. The first measurement waits 45 seconds so Prometheus can scrape the canary more than once. `failureLimit: 1` allows one failed measurement; the second failure fails the whole analysis.

## Attach it to the Rollout

The Rollout points to the template in `strategy.canary.analysis`. `startingStep: 1` starts the analysis when the Rollout reaches step number 1, counted from 0. In the steps below that is the pause after the first weight. The argument `canary-hash` takes its value from `podTemplateHashValue: Latest`, which is the hash of the newest pod template. That means the canary. The pause steps now have durations, so the release moves on without a manual promotion.

Open `rollout-scout.yaml` from the last part and make two changes. Set the message to `good-build`. Then replace the whole `strategy` section with the one below. It drops the header route and its steps, and it adds the `analysis` block:

```yaml
  strategy:
    canary:
      stableService: scout
      canaryService: scout-canary
      trafficRouting:
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: scout-route
            namespace: starfleet
      analysis:
        templates:
          - templateName: scout-success
        startingStep: 1
        args:
          - name: canary-hash
            valueFrom:
              podTemplateHashValue: Latest
      steps:
        - setWeight: 20
        - pause: {duration: 150s}
        - setWeight: 50
        - pause: {duration: 60s}
```

Apply the template and the Rollout. Then wait about 100 seconds and read the `AnalysisRun`, which is one evaluation of the template:

```sh
kubectl apply -f analysistemplate-scout-success.yaml
kubectl apply -f rollout-scout.yaml
kubectl -n starfleet get analysisrun
```

The `AnalysisRun` appears when the Rollout reaches the pause at 20%. Its name is the ReplicaSet name followed by the step. Read its measurements:

```sh
kubectl -n starfleet get analysisrun -o jsonpath='{.items[0].status.phase}{"\n"}{range .items[0].status.metricResults[*]}{.name} {.phase}{"\n"}{range .measurements[*]}  {.phase} {.value}{"\n"}{end}{end}'
```

In one run the output was:

```text
Running
success-rate Running
  Successful [1]
  Successful [1]
  Successful [1]
  Successful [1]
  Successful [1]
```

Prometheus returned a result of 1, so every canary response had a 2xx status. Wait until the Rollout is `Healthy`. In the plugin output the `AnalysisRun` line then showed `✔ Successful` and `✔ 12`, which means 12 passed measurements:

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color | sed -n '16,22p'
```

```text
NAME                               KIND         STATUS        AGE    INFO
⟳ scout                            Rollout      ✔ Healthy     12m    
├──# revision:5                                                      
│  ├──⧉ scout-759bfc7cf7           ReplicaSet   ✔ Healthy     6m51s  stable
│  │  ├──□ scout-759bfc7cf7-w5sf9  Pod          ✔ Running     6m51s  ready:1/1
│  │  └──□ scout-759bfc7cf7-v64ph  Pod          ✔ Running     6s     ready:1/1
│  └──α scout-759bfc7cf7-5         AnalysisRun  ✔ Successful  3m36s  ✔ 12
```

Nobody promoted this release. The pauses ended by themselves, the analysis passed, and the canary became the stable version.

## A faulty canary aborts itself

Now release a canary that returns errors. The podinfo flag `--random-error` makes the application port answer some requests with status 400, 409 or 500. The metrics port 9797 stays clean, so Prometheus can still read the failing numbers. In `rollout-scout.yaml`, change the `command` line to:

```yaml
          command: ["./podinfo", "--port=9898", "--port-metrics=9797", "--random-error"]
```

Apply the file and wait until the Rollout reports `Degraded`, about a minute:

```sh
kubectl apply -f rollout-scout.yaml
kubectl argo rollouts get rollout scout -n starfleet --no-color | sed -n '1,4p'
kubectl -n starfleet get analysisrun --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[-1:]}{.status.message}{"\n"}{range .status.metricResults[*]}{.name} {.phase}{"\n"}{range .measurements[*]}  {.phase} {.value}{"\n"}{end}{end}{end}'
```

The Rollout header and the measurements were:

```text
Name:            scout
Namespace:       starfleet
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 6: Background analysis phase error/failed: Metric "success-rate" assessed Failed due to failed (2) > failureLimit (1)
Metric "success-rate" assessed Failed due to failed (2) > failureLimit (1)
success-rate Failed
  Failed [0.8402364616060706]
  Failed [0.7308974569097741]
```

Only 84% and 73% of the canary's responses were successful. Two failed measurements are more than the `failureLimit` of 1, so the Argo Rollouts controller aborted the release. The plugin then wrote the weights back into the route. Check the route and send 100 requests:

```sh
kubectl -n starfleet get httproute scout-route -o jsonpath='{range .spec.rules[*]}{range .backendRefs[*]}{.name}={.weight} {end}{"\n"}{end}'
kubectl -n starfleet exec deploy/shuttle -- sh -c 'for i in $(seq 1 100); do curl -s -o /dev/null -w "%{http_code}\n" http://$GATEWAY/; done | sort | uniq -c'
```

The output is:

```text
scout=100 scout-canary=0 
    100 200
```

All 100 requests returned status 200 from the stable pods. The faulty canary received no more traffic, and no person had to act. The Rollout stays `Degraded` until you fix the template. As in a release without a router, an abort does not change the desired pod template. Remove `--random-error` from the file and apply it again to return to a healthy template and start a new release.

You can now build a canary that runs the checks for you. The `AnalysisTemplate` defines what a good release means, the `analysis` block starts it at a chosen step, and the router makes the weight a real share of requests, so the measured numbers come from real traffic. Together with the header route, you can test first by hand and then let metrics guard the traffic.

## Common pitfalls

> [!WARNING]
> - **Starting the analysis before the canary gets traffic.** At weight 0 the query has no data. Use `startingStep` at a step after a `setWeight`, and an `initialDelay` for the first scrape.
> - **Treating no data as success.** An empty result fails here, because `len(result) == 1` is false. Do not change the condition to hide missing data.
> - **Pointing the query at the wrong pods.** Without the template hash label, the query also counts the stable pods and can hide a faulty canary.
> - **Using `--full` promotion to skip the gate.** Full promotion skips the remaining steps and the analysis.

## Your mission: Route And Guard A Canary Through The Gateway API

You can now add a header test route to a Rollout, run a background analysis on the canary pods and read an automatic abort. The mission gives you the `scout` Rollout without steps, behind a Gateway API route, with Prometheus installed. You add the `managedRoutes` entry, the header and weight steps and the background analysis, release a good and a faulty template, and prove from the `shuttle` pod that the good one is served.

Pause the playground, then start the lab and read the task:

```sh
astrona stop ats-018-playground-050-04
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-04/labs/lab-01
```

When the Rollout is `Healthy` on the good template, grade your work:

```sh
astrona submit -c sections/section-050/module-04/labs/lab-01
```

Then remove the lab and start the playground again:

```sh
astrona destroy ats-018-lab-050-04
astrona start ats-018-playground-050-04
```
