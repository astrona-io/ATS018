# Question

Solve this question on: `terminal`

The `scout` application in the namespace `starfleet` is an Argo Rollouts `Rollout` with a `blueGreen` strategy. The Service `scout` is the active Service and `scout-preview` is the preview Service. Promotion is manual (`autoPromotionEnabled: false`), and the Rollout has no analysis yet. The `shuttle` pod sends one request per second to both Services.

Prometheus is at `http://kps-prometheus.monitoring.svc:9090`. It scrapes every `scout` pod every 15 seconds. The metric `http_request_duration_seconds_count` has the labels `namespace`, `path` (requests to `/` use `root`), `status` and `rollouts_pod_template_hash`. A new pod needs about 45 seconds before its rate has data.

Gate the releases with a pre-promotion analysis, then prove it works with a good and a faulty candidate. Do not delete the analysis to get a release through and do not use `promote --full`. A watcher named `gate-recorder` in `starfleet` records, for each pod template hash, the `BlueGreenPause`, the `Successful` pre-promotion `AnalysisRun` and whether the active Service switched only after both. Do not delete it or its ConfigMap `gate-trace`. A release promoted with `--full` switches the active Service too early, and `astrona submit` rejects it.

When you finish, these must be true:

- An `AnalysisTemplate` named `scout-success` in `starfleet` has a Prometheus metric that reads the in-cluster address above. It measures the fraction of status `2xx` responses on `path="root"` for one pod template hash, and succeeds at `0.99` or higher. It allows one failed measurement (`failureLimit: 1`).
- The Rollout runs `scout-success` in `prePromotionAnalysis` and passes the hash of the latest (candidate) template to it. `autoPromotionEnabled` stays `false`.
- A good candidate was released first: the pod template environment variable `PODINFO_UI_MESSAGE` is `gated-good`. Its analysis passed and you promoted it.
- A faulty candidate was released next: `PODINFO_UI_MESSAGE` was `bad-release` and the container command had the extra argument `--random-error` (podinfo then answers some requests with status 400, 409 or 500). Its analysis failed and the release was aborted.
- At the end the Rollout is `Healthy` on the good `gated-good` template without `--random-error`, both Services select that template, and a request from the `shuttle` pod to `http://scout.starfleet/` returns the message `gated-good`.

The podinfo container needs the command `./podinfo --port=9898 --port-metrics=9797` (the second port is the metrics port that Prometheus scrapes; keep it).

Check your work with `astrona submit`.
