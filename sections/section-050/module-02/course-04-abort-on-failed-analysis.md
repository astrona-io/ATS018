# Abort A Release On Failed Analysis

The active `scout` configuration returns `gated-good`. Its Rollout, the Argo Rollouts resource that manages release progress, checks each candidate before switching active traffic. An AnalysisRun records the measurements and outcome of that check. Introduce a candidate that accepts connections but returns errors, then prove that analysis protects active users.

## Make the application fail while its pods stay ready

podinfo's `--random-error` option injects Hypertext Transfer Protocol (HTTP) responses with status 400, 409 or 500. The exact sequence is random. A check that counts only server errors would miss the injected client errors. The gate therefore accepts only 200–299 responses and requires a success fraction of at least 99%.

The Transmission Control Protocol (TCP) readiness probe checks whether port 9898 accepts connections. It deliberately does not judge response quality. The dedicated metrics port 9797 does not inject errors, so Prometheus, the system that collects application measurements, can still scrape the faulty pods reliably. This separates container availability, metric collection and release acceptance.

<!-- astrona:playground:renew -->

Save this as `rollout-scout-bad.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: scout
  namespace: starfleet
spec:
  replicas: 2
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      containers:
      - name: scout
        image: ghcr.io/stefanprodan/podinfo:6.15.0
        command:
        - ./podinfo
        - --port=9898
        - --port-metrics=9797
        - --random-error
        env:
        - name: PODINFO_UI_MESSAGE
          value: bad-release
        ports:
        - name: http
          containerPort: 9898
        - name: metrics
          containerPort: 9797
        readinessProbe:
          tcpSocket:
            port: http
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 64Mi
  strategy:
    blueGreen:
      activeService: scout
      previewService: scout-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: scout-success
        args:
        - name: candidate-hash
          valueFrom:
            podTemplateHashValue: Latest
```

The image remains 6.15.0. The command argument and message create a new template with faulty behaviour. The existing `scout-success` AnalysisTemplate defines the query and conditions. `Latest` passes the new candidate's hash, the identifier computed from its pod template, into that query.

Apply it:

```sh
kubectl apply -f rollout-scout-bad.yaml
```

```text
rollout.argoproj.io/scout configured
```

Then check the preview after the new pods become ready and Service endpoints settle. A Service provides a stable address and selects ready pods by labels. Send a request each second for 20 seconds so the sample covers more than one short burst:

```sh
kubectl -n starfleet exec deploy/shuttle -- sh -c 'for request_number in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code}\n" http://scout-preview; sleep 1; done'
```

The real sample returned:

```text
500
200
409
200
200
500
200
200
200
200
200
200
200
200
200
200
200
200
200
409
```

Some requests succeed and others fail. Your exact sample will differ. These requests use the preview address, while the separate active address still selects the stable configuration. The background `shuttle` requests continue after this short sample ends and provide the analysis measurements.

## Read the failed run and the retained active selector

Wait about 90 seconds after applying the candidate, then inspect the run and release. `failureLimit: 1` permits one failed measurement, but a second failure aborts this release before the planned third measurement.

```sh
kubectl -n starfleet get analysisrun -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,COUNT:.status.metricResults[0].count,SUCCESSFUL:.status.metricResults[0].successful,FAILED:.status.metricResults[0].failed'
ANALYSIS_RUN=$(kubectl -n starfleet get rollout scout -o jsonpath='{.status.blueGreen.prePromotionAnalysisRunStatus.name}')
kubectl -n starfleet get analysisrun "$ANALYSIS_RUN" -o jsonpath='{range .status.metricResults[0].measurements[*]}{.phase}{" "}{.value}{"\n"}{end}'
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet get service scout scout-preview -o custom-columns='NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep -E '"(version|message)"'
```

The analysis table and measurements were:

```text
NAME                     PHASE        COUNT   SUCCESSFUL   FAILED
scout-74d8c484cb-3-pre   Successful   3       3            <none>
scout-8b8bd5866-4-pre    Failed       2       <none>       2
Failed [0.717108753998877]
Failed [0.6979243966792101]
```

The plugin's status header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 4: Blue/green pre-promotion analysis phase error/failed: Metric "success-rate" assessed Failed due to failed (2) > failureLimit (1)
Strategy:        BlueGreen
Images:          ghcr.io/stefanprodan/podinfo:6.15.0 (active, preview, stable)
Replicas:
  Desired:       2
  Current:       4
  Updated:       2
  Ready:         2
  Available:     2
```

The Service selector and response output from the same command block was:

```text
NAME            HASH
scout           74d8c484cb
scout-preview   8b8bd5866
  "version": "6.15.0",
  "message": "gated-good",
```

Both measurements were well below `0.99`. The failure message names `success-rate` and explains that two failures exceeded the limit of one. The Rollout is Degraded, but the active Service still selects the `gated-good` template and returns that message. Degraded describes the unsuccessful release; it does not mean all active requests fail.

The preview selector can still name the failed candidate while the controller delays scaling its pods down. It does not become proof of a successful release just because a preview pod stays ready. The stable ReplicaSet, the resource that keeps pods from the accepted template running, retains active traffic.

## Repair desired state after the abort

Abort does not remove the faulty argument from the desired template. Read what the Rollout still requests:

```sh
kubectl -n starfleet get rollout scout -o jsonpath='{.spec.template.spec.containers[0].command}{"\n"}{.spec.template.spec.containers[0].env[0].value}{"\n"}'
```

```text
["./podinfo","--port=9898","--port-metrics=9797","--random-error"]
bad-release
```

The random error flag and `bad-release` remain. Retrying this unchanged template would run the same faulty application again. Deleting its AnalysisRun also does not repair the desired application.

Restore the saved `rollout-scout-gated.yaml`, which uses `gated-good` and has no random error argument. This returns desired state to the configuration that is already stable. Apply it:

```sh
kubectl apply -f rollout-scout-gated.yaml
```

```text
rollout.argoproj.io/scout configured
```

Then check the result:

```sh
kubectl argo rollouts status scout -n starfleet --timeout 120s
kubectl -n starfleet get service scout scout-preview -o custom-columns='NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep -E '"(version|message)"'
```

```text
Healthy
NAME            HASH
scout           74d8c484cb
scout-preview   74d8c484cb
  "version": "6.15.0",
  "message": "gated-good",
```

The Rollout is Healthy, both Services select the accepted template, and active traffic returns `gated-good`. This correction reuses the stable configuration. A different corrected pod template would start a new candidate and run the pre-promotion check again. In a GitOps environment, where a controller applies desired state from Git, commit the correction there instead of relying on a live change.

## Decide whether to check before or after promotion

`prePromotionAnalysis` runs before the active Service switch. The faulty candidate in this example never served active requests. That protection depends on generating representative preview traffic; no active user traffic reaches the candidate yet.

`postPromotionAnalysis` runs after the active Service switches to the candidate. The controller can then judge real active traffic. If that analysis fails, Argo Rollouts aborts and switches the active selector back to the previous stable ReplicaSet. Users can receive candidate errors during the measurement window, so this check provides recovery rather than preventing all exposure.

Keep the stable replicas available throughout post-promotion measurement. This template waits 45 seconds before its first sample and can take about 75 seconds to finish. A 30-second scale-down delay is too short for that plan. Give the old replicas enough time to remain available while the check completes and a failed release switches back.

You have proved that a ready application can fail release analysis while stable users keep receiving successful responses. Reading the AnalysisRun values, Service selectors and real responses together explains the abort, and correcting the saved template restores the desired release state.

## Common pitfalls

> [!WARNING]
> - **Counting 400 and 409 responses as successful application requests.** They are part of podinfo's injected fault too.
> - **Scraping the faulty application's `/metrics` endpoint on port 9898.** Random errors can hide measurements; use the separate metrics port.
> - **Retrying an unchanged bad template.** The error flag remains after abort until you remove it from desired state.
> - **Expecting post-promotion analysis to prevent all exposure.** Active traffic reaches the candidate while that check runs.
