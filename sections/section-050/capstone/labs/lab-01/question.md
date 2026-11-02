# Question

Solve this question on: `terminal`

The `scout` application in the namespace `starfleet` is an Argo Rollouts `Rollout` with a `canary` strategy. It runs 4 replicas of the template with `PODINFO_UI_MESSAGE` set to `stable`. The steps are `setWeight: 25`, an indefinite `pause`, `setWeight: 50` and a `pause` of 20 seconds. The Service `scout` selects all `scout` pods. The `shuttle` pod sends five requests per second to `http://scout.starfleet/`.

The Rollout already starts the `AnalysisTemplate` `scout-success` as a background analysis from step 1, but the gate does not work. Find out why and fix it. Look at the `AnalysisRun` of a test release to see what the analysis measures. The Rollout has no traffic router, so the canary pod receives its share of requests through the Service.

Prometheus is at `http://kps-prometheus.monitoring.svc:9090`. It scrapes every `scout` pod every 15 seconds. The metric `http_request_duration_seconds_count` has the labels `namespace`, `path` (requests to `/` use `root`), `status` and `rollouts_pod_template_hash`. A new pod needs about 45 seconds before its rate has data.

Then release two candidates. Do not delete the analysis, do not lower the `0.99` threshold, and do not use `promote --full`.

When you finish, these must be true:

- The `AnalysisTemplate` `scout-success` measures the fraction of status `2xx` responses on `path="root"` for one pod template hash, succeeds at `0.99` or higher and allows one failed measurement (`failureLimit: 1`).
- The Rollout runs `scout-success` as a background analysis and passes the hash of the latest (candidate) template to the argument `candidate-hash`. The steps keep their pause.
- A faulty candidate was released first: `PODINFO_UI_MESSAGE` was `bad-release` and the container command had the extra argument `--random-error` (podinfo then answers some requests with status 400, 409 or 500). Its analysis failed on real measurements and the release was aborted, while the stable pods kept serving `stable`.
- A good candidate was released next: `PODINFO_UI_MESSAGE` is `canary-good`. Its analysis passed and you promoted it.
- At the end the Rollout is `Healthy` on the `canary-good` template without `--random-error`, the stable ReplicaSet is the current one, 4 replicas are available, and every request from the `shuttle` pod to `http://scout.starfleet/` returns the message `canary-good`.

The podinfo container needs the command `./podinfo --port=9898 --port-metrics=9797` (the second port is the metrics port that Prometheus scrapes; keep it).

Check your work with `astrona submit`.
