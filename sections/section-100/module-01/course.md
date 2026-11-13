# Plan And Apply Kubernetes Resources With OpenTofu

A platform change needs a review before it reaches a cluster. OpenTofu is an
infrastructure as code tool that reads configuration, compares it with real
resources and proposes a plan. You run an apply operation to make that plan
happen. This compact module covers the simulator tasks: read state, save a
plan, change an attribute and add a resource.

The module has four parts. **Read A Working Directory And Its State** explains
which files describe the desired configuration and which record resource
identity. **Review And Apply An Attribute Change** saves a readable diff and
changes the replica count. **Add A Service And Understand Reconciliation**
connects an existing Deployment to a Service and compares OpenTofu with
Crossplane, a Kubernetes controller framework for managing resources.
**Tell Three Kinds Of Plan Changes Apart** reads a plan for the reason behind
each change: a pending update, a new resource or live drift.

## Learning objectives

- Inspect local state and initialize a directory without losing resource identity.
- Save a human-readable plan, review it and apply an attribute change.
- Add a `kubernetes_service` for an existing `kubernetes_deployment` and prove it serves requests.
- Explain when OpenTofu repairs drift and how that differs from continuous reconciliation.
- Tell a pending update, a new resource and live drift apart in a saved plan.

## Before you start

Know Kubernetes namespaces, Deployments, Services, labels and selectors. A
Deployment maintains the requested number of pods. A Service gives matching
pods a stable network address. You need no cloud account.

The playground installs OpenTofu 1.13.2 and Kubernetes provider 3.4.0 on the
terminal. A provider is a plugin that reads and changes a remote system through
its application programming interface (API). These examples use the provider's
`kubernetes_deployment` and `kubernetes_service` resource names. Version 3.4.0
supports them but marks them deprecated in favor of `kubernetes_deployment_v1`
and `kubernetes_service_v1`. Keep the supplied names so the state addresses
remain the same.

Work in `~/resources/tofu/scout`. Bootstrap creates a `scout` Deployment in
`starfleet` with one replica and saves genuine local state. There is no `scout`
Service. The `shuttle` Deployment in `starfleet` supplies the request client.
The cluster preloads podinfo 6.15.0 and curl 8.22.0. Commands run on the terminal
where `kubectl` already points at this playground.

<!-- astrona:playground -->
