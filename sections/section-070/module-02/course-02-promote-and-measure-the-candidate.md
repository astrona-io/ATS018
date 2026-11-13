# Promote And Measure The Candidate

The `scout` Rollout is paused with `preview-good` behind `scout-preview` and `stable` behind `scout`. A Rollout is the Argo Rollouts resource that manages release progress. A Service selects ready pods and gives them a stable address. Promotion lets the controller change the active Service selector to the tested candidate.

<!-- astrona:playground:renew -->

```sh
kubectl argo rollouts promote scout -n starfleet
```

```text
rollout 'scout' promoted
```

Normal promotion clears this release pause. The controller switches active traffic to the candidate ReplicaSet, the Kubernetes resource that keeps pods from one template running. It does not need to replace every active pod at the moment of the switch.

## Read routing before replica counts

Check immediately after the controller switches the selector:

```sh
kubectl -n starfleet get service scout scout-preview -o custom-columns='NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash'
kubectl -n starfleet get rs -l app=scout -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas'
```

```text
NAME            HASH
scout           5849b6755f
scout-preview   5849b6755f
NAME               DESIRED   READY
scout-5849b6755f   2         2
scout-5b574f8446   2         2
```

Both Services now select `5849b6755f`, but the old ReplicaSet still has two ready pods. The configured 30-second scale-down delay gives nodes time to update Service networking. Old pods still running does not mean the Service intentionally divides new requests between the two templates. Existing connections and network propagation can briefly outlast a selector change.

Wait at least 30 seconds after promotion, then check the replica counts and response:

```sh
kubectl -n starfleet get rs -l app=scout -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep -E '"(version|message)"'
```

```text
NAME               DESIRED   READY
scout-5849b6755f   2         2
scout-5b574f8446   0         <none>
  "version": "6.15.0",
  "message": "preview-good",
```

The old desired count is now zero; `<none>` means the ready count field is absent. The active response contains `preview-good`. A release can report Healthy before delayed old replicas finish shutting down, so inspect routing and counts separately.

## Choose a metric for application requests

Prometheus is a monitoring system that scrapes numeric measurements from applications and stores them as time series. A time series is one metric name with one set of labels and its timestamped values. The playground's PodMonitor tells the Prometheus Operator which `scout` pods to scrape. The operator translates that resource into Prometheus configuration.

Read podinfo's measurements through the preview Service:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout-preview/metrics | grep -E '^http_requests_total|^http_request_duration_seconds_count.*path="root"'
```

```text
http_request_duration_seconds_count{method="GET",path="root",status="200"} 32
http_requests_total{status="200"} 32
```

`http_requests_total` is a counter, a value that accumulates events. It has a `status` label but no request path label. Its count can include readiness checks and other endpoints. `http_request_duration_seconds` is a histogram, a metric that records request durations in buckets; its `_count` series counts requests and also has `method`, `path` and `status` labels.

Use the histogram's count for the release check so the query can select `path="root"`, podinfo's label for requests to `/`. This avoids healthy readiness checks diluting the application's error rate. Define success here as a Hypertext Transfer Protocol (HTTP) response in the 200–299 range. Client errors such as 400 and 409 fail this definition, as do server errors such as 500.

Prometheus Query Language (PromQL) selects and calculates time series. `rate(...[2m])` estimates requests per second from a counter over the last two minutes. Summing the successful response rate and dividing by the total rate gives a fraction between zero and one. A fraction of `1` means every measured request succeeded under this definition.

## Select only the candidate template

The PodMonitor copies `rollouts-pod-template-hash` from each pod. Prometheus exposes it as `rollouts_pod_template_hash`, with underscores. Read the preview Service's hash and use it in both sides of the query:

```sh
CANDIDATE_HASH=$(kubectl -n starfleet get service scout-preview -o jsonpath='{.spec.selector.rollouts-pod-template-hash}')
kubectl -n starfleet exec deploy/shuttle -- curl -sG http://kps-prometheus.monitoring.svc:9090/api/v1/query --data-urlencode "query=sum(rate(http_request_duration_seconds_count{namespace=\"starfleet\",path=\"root\",rollouts_pod_template_hash=\"$CANDIDATE_HASH\",status=~\"2..\"}[2m])) / sum(rate(http_request_duration_seconds_count{namespace=\"starfleet\",path=\"root\",rollouts_pod_template_hash=\"$CANDIDATE_HASH\"}[2m]))"
```

The HTTP application programming interface (API), an endpoint that accepts program requests, returned this JavaScript Object Notation (JSON) response:

```text
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1791825490.660,"1"]}]}}
```

The value is `1`. The other number is the evaluation timestamp and will differ in your run. The `metric` object is empty because `sum` aggregates the selected pod series into one result. The success of the API request says that Prometheus evaluated the query; the value itself says whether the application passed.

The stable configuration and candidate must never share one release-wide success calculation. Good stable requests can hide candidate errors. Selecting the preview hash isolates the template being tested, and steady preview traffic provides measurements before active users reach it. Wait for at least two scrapes after a new candidate starts; an empty result or no traffic is not proof of success.

You have switched a manually tested configuration, observed delayed scale-down and calculated a success fraction for one template. Prometheus can now provide the evidence, but a controller still needs conditions that turn that evidence into a release decision.

## Common pitfalls

> [!WARNING]
> - **Equating old running pods with active traffic.** Read the Service selector as well as replica counts.
> - **Querying every `scout` pod together.** Stable requests can hide candidate failures.
> - **Adding a path filter to `http_requests_total`.** That podinfo counter has no path label; use the histogram's count series.
> - **Treating an empty result as 100% success.** Check scraping and preview traffic before accepting a release.
