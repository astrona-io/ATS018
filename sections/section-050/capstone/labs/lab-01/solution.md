# Solution

The gate has two faults. The Rollout passes the hash of the stable template to the analysis, so the analysis never judges the candidate. The query selects `path="/"`, but podinfo labels requests to `/` with `path="root"`, so the query returns no data. You find both by releasing a test candidate and reading its `AnalysisRun`.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-050/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Read the gate

Show how the Rollout runs the analysis:

```sh
kubectl -n starfleet get rollout scout -o jsonpath='{.spec.strategy.canary.analysis}{"\n"}'
```

```text
{"args":[{"name":"candidate-hash","valueFrom":{"podTemplateHashValue":"Stable"}}],"startingStep":1,"templates":[{"templateName":"scout-success"}]}
```

The argument `candidate-hash` takes `podTemplateHashValue: Stable`. The analysis measures the pods of the stable ReplicaSet, not the candidate.

## Step 2: Release a test candidate and read the AnalysisRun

Change the message to start a release:

```sh
kubectl -n starfleet patch rollout scout --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"first-try"}]'
```

After about two minutes, list the measurements:

```sh
kubectl -n starfleet get analysisrun -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.args}{" "}{.status.phase}{" "}{.status.metricResults[0].measurements[*].value}{"\n"}{end}'
```

```text
scout-6885d97b47-2 [{"name":"candidate-hash","value":"5b574f8446"}] Failed [] []
```

The hash `5b574f8446` is the stable ReplicaSet, not the new one (`6885d97b47`). The measurements are `[]`, an empty result. The query matched no series, so the Rollout aborted and shows `Degraded`. The hash values differ on your cluster.

## Step 3: Fix the gate

Save this as `analysistemplate-scout-success.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: scout-success
  namespace: starfleet
spec:
  args:
    - name: candidate-hash
  metrics:
    - name: success-rate
      initialDelay: 45s
      interval: 20s
      count: 3
      failureLimit: 1
      successCondition: len(result) == 1 && result[0] >= 0.99
      failureCondition: len(result) != 1 || result[0] < 0.99
      provider:
        prometheus:
          address: http://kps-prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.candidate-hash}}",status=~"2.."}[2m]))
            /
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.candidate-hash}}"}[2m]))
```

Apply it:

```sh
kubectl apply -f analysistemplate-scout-success.yaml
```

In the Rollout, change `podTemplateHashValue: Stable` to `podTemplateHashValue: Latest`. Edit the `scout` Rollout (`kubectl -n starfleet edit rollout scout`) so the analysis reads:

```yaml
      analysis:
        startingStep: 1
        templates:
          - templateName: scout-success
        args:
          - name: candidate-hash
            valueFrom:
              podTemplateHashValue: Latest
```

## Step 4: Release the faulty candidate

Set `PODINFO_UI_MESSAGE` to `bad-release` and add `--random-error` to the container command, after `--port-metrics=9797`. The canary pod then answers some requests with status 400, 409 or 500. The Rollout pauses at step 1 and the analysis starts.

After about 85 seconds the analysis fails on a real measurement and the Rollout aborts. Check the result:

```sh
kubectl -n starfleet get analysisrun -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{" "}{.status.metricResults[0].measurements[*].value}{"\n"}{end}'
```

```text
scout-8b8bd5866-3 Failed [0.7027027027027026] [0.6966302853648781]
```

The success rate is about 0.70, below 0.99. The stable pods keep serving `stable`.

## Step 5: Release the good candidate

Remove `--random-error` and set `PODINFO_UI_MESSAGE` to `canary-good`. A new template clears the abort. The Rollout pauses at step 1 and the analysis runs again. When the `AnalysisRun` shows `Successful`, promote:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl argo rollouts status scout -n starfleet
```

The final `AnalysisRun` shows `scout-6474d4d595-4 Successful [1] [1] [1]`. Do not promote before it succeeds.

## Step 6: Check the result

Wait until the Rollout is `Healthy`, then send requests from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet/
```

```text
  "version": "6.15.0",
  "message": "canary-good",
```

The output is shortened to two lines. The stable ReplicaSet is now the one of `canary-good`, and 4 replicas are available.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-050/capstone/labs/lab-01
```
