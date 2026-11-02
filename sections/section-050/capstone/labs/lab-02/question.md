# Question

Solve this question on: `terminal`

The `scout` application in the namespace `starfleet` is an Argo Rollouts `Rollout` with a `canary` strategy. It uses the Gateway API plugin `argoproj-labs/gatewayAPI` with the `HTTPRoute` `scout-route` (Services `scout` and `scout-canary`). The team wrote a release setup for it: a header test route, a weighted split and a background analysis from the `AnalysisTemplate` `scout-success`. The setup does not work. The `shuttle` pod sends requests to the Gateway and has its address in the environment variable `GATEWAY`. The stable pod template has `PODINFO_UI_MESSAGE=stable`.

Prometheus is at `http://kps-prometheus.monitoring.svc:9090` and scrapes every `scout` pod. The metric `http_request_duration_seconds_count` has the labels `namespace`, `path` (requests to `/` use `root`), `status` and `rollouts_pod_template_hash`. A new pod needs about 45 seconds before its rate has data.

Find out what is wrong and repair the Rollout and the AnalysisTemplate. Then prove the setup with a good and a faulty canary. Testers send the header `x-canary: yes` to reach the canary before it gets any weighted traffic. Do not delete the analysis, do not lower the `0.99` threshold, and do not use `promote --full`.

When you finish, these must be true:

- The Rollout lists a managed route named `canary-header` in `trafficRouting.managedRoutes`. Its steps start with `setCanaryScale` (1 replica), then `setHeaderRoute` named `canary-header` that matches the header `x-canary` with the exact value `yes`, then a `pause` with no duration. After that come weight steps (the existing `setWeight` and timed `pause` steps may stay).
- The `AnalysisTemplate` `scout-success` measures the fraction of status `2xx` responses on `path="root"` for one pod template hash. It succeeds at `0.99` or higher and allows one failed measurement (`failureLimit: 1`).
- The Rollout runs `scout-success` as a background analysis that starts at a step after the first weight step, and passes the hash of the latest template to it.
- A good canary was released first: `PODINFO_UI_MESSAGE` was `good-build`. You tested it with the header, promoted it, and its analysis passed.
- A faulty canary was released next: the command had the extra argument `--random-error` (podinfo then answers some requests with status 400, 409 or 500). Its analysis failed and the release was aborted.
- At the end the Rollout is `Healthy` on the `good-build` template without `--random-error`, the managed header rule is gone from `scout-route`, the route sends 100 percent to `scout`, and requests from `shuttle` to `http://$GATEWAY/` return status 200 and the message `good-build`.

Keep the container command `./podinfo --port=9898 --port-metrics=9797` (the second port is the metrics port that Prometheus scrapes).

Check your work with `astrona submit`.
