# Automate Canary Analysis With Flagger

A canary release sends a growing share of traffic to a new version and stops when the metrics turn bad. Someone has to move the weight, read the metrics and decide. Flagger is a Kubernetes operator (a controller that manages other resources) that does this loop for you. You write one `Canary` object, and Flagger moves the traffic, queries Prometheus and either promotes the new version or rolls it back.

Flagger works differently from Argo Rollouts. It does not replace your Deployment with a new resource kind. It keeps the Deployment and creates a copy of it called the primary. For canary releases it changes the weights of a service mesh (here Istio) between the primary and the canary pods. For blue/green it can use the Kubernetes provider without a mesh or metrics backend. The `scout` Deployment you already have stays the object you edit.

Keep one sentence in mind for this module: **change the Deployment, and Flagger runs the release.** The module has six parts. The first creates a `Canary` and reads the objects Flagger generates. The second changes the image and follows a canary to promotion. The third deploys a version that returns errors and proves Flagger rolls it back while the old version keeps serving. The fourth uses mesh-free blue/green analysis, checks the candidate with a pre-rollout HTTP webhook and saves the Canary events. The fifth holds a new template with a `confirm-rollout` webhook, explains what Flagger does each interval while the gate is closed, and controls the load tester gate. The sixth moves the gate to the promotion point with `confirm-promotion`, shows which checks keep running while the candidate waits, and follows the phases from `WaitingPromotion` to `Succeeded`.

## Learning objectives

After this module you can:

- Create a `Canary` that targets a Deployment and name the primary and canary objects Flagger creates.
- Set `interval`, `threshold`, `stepWeight` and `maxWeight` and the built-in `request-success-rate` metric.
- Trigger a canary by changing the Deployment image and follow it in the `Canary` status and events.
- Generate test traffic during the analysis with the Flagger load tester webhook.
- Configure Kubernetes blue/green with iterations, an empty metrics list and a synchronous HTTP gate.
- Trigger an environment-variable release and save its Canary events.
- Require manual approval before rollout or before promotion with confirmation webhooks, read the phase and status fields while a gate is closed, and control the load tester gate.
- Compare how Flagger and Argo Rollouts each take over a workload.

## Before you start

You need Kubernetes basics: Deployments, Services, labels and readiness probes. You also need `kubectl apply`, `kubectl get` and `kubectl exec`. Knowing what a canary release is helps, but the first part explains it again.

The playground runs Kubernetes 1.35.8, Istio 1.30.7 (a service mesh that routes requests through sidecar proxies), Flagger 1.45.0 and the Flagger load tester. Istio's bundled Prometheus collects request metrics from the sidecar proxies. Flagger queries that Prometheus.

| Namespace | What is in it |
| --- | --- |
| `istio-system` | The Istio control plane (`istiod`), Istio's Prometheus and the Flagger controller |
| `starfleet` | The `scout` Deployment (podinfo 6.14.0, one replica) with a Service, the `shuttle` client and the `flagger-loadtester` |

Sidecar injection is on in `starfleet`, so every pod there has an Envoy sidecar proxy. No `Canary` exists yet. The commands in this module use the `kubectl` context of the playground; check it with `kubectl config current-context` if another cluster is running on your machine.

The mesh-free blue/green and manual approval labs each use a separate environment with Flagger and its load tester only. Pause the Istio playground before starting either lab.

Write the YAML files in an empty folder on your machine. No GitOps controller manages these objects, so you apply changes directly. In a GitOps environment you would put the same Deployment and `Canary` in Git.

<!-- astrona:playground -->
