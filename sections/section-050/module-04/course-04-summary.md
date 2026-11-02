# Summary

A traffic router decides which backend receives each request. Argo Rollouts does not route requests itself. It writes its decisions into a router, here a Kubernetes Gateway API `HTTPRoute`, through a traffic router plugin that the controller downloads and starts. The `Rollout` names the plugin, the route and the two Services, `stableService` and `canaryService`.

With a router, `setWeight` is a share of requests. A weight of 10% sent about 11 of 100 requests to the canary while three pods ran, and a weight of 50% sent 50 of 100. The pod count only gives the canary enough capacity. A short sample can differ from the weight, because the router chooses a backend at random for each request, so count at least 100 requests.

A header route sends requests with a chosen header to the canary only. The `Rollout` lists the rule under `managedRoutes`, the step `setCanaryScale` keeps a canary pod running while the weight is 0, and the step `setHeaderRoute` creates the rule in the `HTTPRoute`. The plugin removes the rule when the release ends. Requests without the header keep using the stable pods.

A background analysis checks the canary while the later steps run. The `AnalysisTemplate` holds a Prometheus query, a success condition and a failure condition. The `analysis` block starts it at `startingStep` and gives it the canary's pod template hash. When failed measurements pass the `failureLimit`, the controller aborts the release, the plugin sets the weights back to 100% stable, and the `Rollout` reports `Degraded`. An abort does not change the desired pod template, so fix the template before the next release.

Key facts:

- The Gateway API plugin is `argoproj-labs/gatewayAPI`, version v0.17.0 with Argo Rollouts 1.10.0.
- The controller needs permission to get and update `HTTPRoute` objects and to get Services.
- Prove a split with a count of responses, and prove an abort with the route weights and the response codes.

<!-- astrona:playground:destroy -->
