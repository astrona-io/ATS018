# Shift Canary Traffic With Argo Rollouts And A Traffic Router

A canary release sends a part of the traffic to a new version and checks it before the rest follows. Without a traffic router, Argo Rollouts can only approximate that part with pod counts. With a traffic router, the controller sets a real share of requests. It can also send only requests with a chosen header to the canary, and it can check the canary's metrics while the release runs.

This module connects Argo Rollouts to the Kubernetes Gateway API through a plugin. The module has three parts. The first splits requests by weight and proves the split with a count of responses. The second routes test requests to the canary by header. The third adds a background analysis that aborts a release with a failing canary.

## Learning objectives

After this module you can:

- Connect a `Rollout` to an `HTTPRoute` with `trafficRouting` and the Gateway API plugin.
- Explain why a weight is a share of requests and not a pod ratio, and prove it with a response count.
- Route test requests to the canary with `managedRoutes`, `setCanaryScale` and `setHeaderRoute`.
- Write an `AnalysisTemplate` for Prometheus and attach it as a background analysis with `startingStep`.
- Read an aborted release and prove that the stable version serves all requests.

## Before you start

You need Kubernetes basics (Deployments, Services, labels) and the `kubectl` commands `apply`, `get` and `exec`. The Argo Rollouts `kubectl` plugin must be on your `PATH`. Knowing what a canary release is helps, but the first part explains it again.

The playground runs Kubernetes 1.35.8, Argo Rollouts 1.10.0 with the Gateway API plugin v0.17.0, Envoy Gateway as the Gateway API controller, and a small Prometheus.

| Namespace | What is in it |
| --- | --- |
| `argo-rollouts` | The Argo Rollouts controller, which downloads and starts the plugin |
| `envoy-gateway-system` | Envoy Gateway, the controller that applies `Gateway` and `HTTPRoute` objects |
| `monitoring` | Prometheus and the Prometheus Operator |
| `starfleet` | The `scout` Rollout (podinfo 6.14.0, two replicas), the Services `scout` and `scout-canary`, a `Gateway`, an `HTTPRoute`, a PodMonitor and the `shuttle` client |

The `shuttle` pod sends a request to the Gateway about five times a second, and its `GATEWAY` environment variable holds the Gateway address. The commands in this module use the `kubectl` context of the playground; check it with `kubectl config current-context` if another cluster is running on your machine.

Write the YAML files in an empty folder on your machine. No GitOps controller manages these objects, so you apply changes directly. In a GitOps environment you would put the same files in Git.

<!-- astrona:playground -->
