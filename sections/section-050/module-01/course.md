# Roll Out A Canary With Argo Rollouts

A Kubernetes Deployment replaces old pods as new pods become ready. That proves the containers can start, but it gives you no planned stop to test a small release before replacing the rest. A canary release sends some traffic to a new version while a stable version still serves the remaining traffic.

Argo Rollouts adds those stops. Its `Rollout` resource replaces a Deployment and tells the Argo Rollouts controller how to change the replica counts. A replica is one copy of a pod. A ReplicaSet is the Kubernetes resource that keeps those copies running from one pod template.

Keep one sentence in mind for this module: **without a traffic router, Argo Rollouts approximates canary weight by changing replica counts.** A traffic router is a component that controls the share of requests sent to each version. This playground has one Service and no traffic router, so the replica split matters more than any short request sample.

The module has four parts. **Convert A Deployment Into A Rollout** replaces the starting Deployment and establishes a stable version. **Canary Steps And Replica Weights** changes the image, watches a pause and checks both versions through one Service. **Promote And Pause A Canary** advances the steps and tests an explicit pause. **Abort And Retry A Release** stops an invalid image, proves the stable version still serves requests, and retries a corrected release.

## Learning objectives

After this module you can:

- Convert a Deployment into a Rollout with `setWeight` and `pause` steps.
- Follow a release with `kubectl argo rollouts get rollout --watch`.
- Promote, pause and abort a release, and identify the ReplicaSet serving traffic.
- Explain why replica counts approximate a weight without a traffic router.
- Correct an image and retry an aborted release.

## Before you start

You need Kubernetes basics: namespaces, Deployments, Services, labels, selectors and readiness probes. A readiness probe is a check that tells Kubernetes whether a pod can receive Service traffic. You also need `kubectl get`, `kubectl apply` and `kubectl exec`.

The playground runs Kubernetes 1.35.8 with the Argo Rollouts 1.10.0 controller in `argo-rollouts`. Use `kubectl` 1.35.8 and the `kubectl-argo-rollouts` plugin version 1.10.0 on your machine. A plugin is an executable that `kubectl` finds on your shell's `PATH`; this one provides the `kubectl argo rollouts` commands. The controller runs the releases in the cluster even when the plugin is closed.

| Namespace | What is in it |
| --- | --- |
| `argo-rollouts` | The Argo Rollouts controller and its custom resource definitions |
| `starfleet` | `scout`, a Deployment with five podinfo 6.14.0 replicas; the `scout` Service; and the `shuttle` request client |

podinfo is a small web application that returns a JavaScript Object Notation (JSON) response with its version. The node already holds images 6.14.0 and 6.15.0. No Rollout, traffic router or metrics provider exists. No GitOps controller manages these objects, so you change them directly with `kubectl`. A GitOps controller reads desired state from Git and applies it to the cluster; in that environment, also record workload changes in Git.

Write the manifest in a folder on your machine and keep the playground running while you read the parts. Every command uses the playground's Kubernetes context.

<!-- astrona:playground -->
