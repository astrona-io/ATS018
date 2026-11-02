# Summary

Flagger runs a canary release for a Deployment that you keep editing. A `Canary` object names the Deployment and holds the release policy. Flagger creates a primary Deployment that serves the traffic, canary pods for the new version, a primary and a canary Service, two Istio `DestinationRule` objects and a `VirtualService`. During a release it changes only the weights in the `VirtualService`.

## What you learned

A release starts when the pod template of the target Deployment changes. Flagger raises the canary weight by `stepWeight` every `interval` until `maxWeight`. At each step it queries Prometheus for the built-in `request-success-rate` metric and runs the webhooks. The load tester webhook sends requests to the canary so the metric has data. When the metric has no values, Flagger halts and does not promote.

If a check fails, Flagger counts it. When the count reaches `threshold`, it sets the canary weight to 0, scales the canary down and marks the `Canary` as `Failed`. The primary pods keep serving the last good version during the whole release. Flagger does not repair the Deployment: the fix is a new pod template. When all steps pass, Flagger copies the canary template into the primary and marks the `Canary` as `Succeeded`.

Flagger and Argo Rollouts solve the same problem in different ways:

- Flagger keeps the Deployment and creates a primary copy. Argo Rollouts replaces the Deployment with a `Rollout`.
- Flagger needs a traffic provider (here Istio) to move weights. Argo Rollouts can approximate weights with replica counts when no router exists.
- Flagger runs the whole loop from the `Canary` analysis block. Argo Rollouts uses steps with `pause`, and uses an `AnalysisTemplate` for metrics.
- Both stop on a bad metric and keep the old version serving.

<!-- astrona:playground:destroy -->
