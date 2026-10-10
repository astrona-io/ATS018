# Build Environment Overlays With Kustomize

A GitOps controller does one thing again and again: it reads manifests from a Git repository, renders them, and makes the cluster match. That only works if the same files always render to the same output. It also has to work for more than one environment, because staging and production almost never run the exact same configuration.

Kustomize is the tool most platforms use for this job. Kustomize is a configuration tool that builds Kubernetes manifests from a set of plain YAML files and a `kustomization.yaml` file. It is built into `kubectl`, and both Argo CD and Flux render Kustomize directories without any extra setup. It needs no template language: every input file is a valid Kubernetes manifest, and Kustomize changes copies of them.

Keep one sentence in mind for this module: **one base holds what every environment shares, and each overlay holds only what makes its environment different.** You will build a base for the `scout` application, then a staging overlay and a production overlay on top of it. You will render each one, compare it with the cluster, apply it, and read the errors Kustomize prints when a file is wrong.

The module has four parts. **One Base, Rendered Before It Is Applied** builds the base and its `kustomization.yaml`, and renders it without touching the cluster. **Overlays And Patches** adds the two environments and changes namespaces, image tags, replicas and resources with the two kinds of patch. **Generators, Diff And Apply** generates a ConfigMap, shows why its name ends in a hash, and takes the overlays to the cluster with `kubectl diff -k` and `kubectl apply -k`. **Reading Kustomize Build Errors** breaks the files on purpose and reads each error, including the one mistake Kustomize does not report.

## Learning objectives

After this module you can:

- Write a `kustomization.yaml` that lists resources, adds labels and sets an image tag for a base.
- Create staging and production overlays that change the replica count and the resources of one base.
- Render an overlay with `kubectl kustomize` and compare it with the cluster using `kubectl diff -k`.
- Generate a ConfigMap with `configMapGenerator` and explain why its name carries a hash suffix.
- Diagnose a Kustomize build error caused by a wrong resource path or a patch that matches no object.

## Before you start

You need Kubernetes basics: namespaces, Deployments, Services, labels and selectors, ConfigMaps, and the commands `kubectl get`, `kubectl apply` and `kubectl exec`. You do not need Helm or any GitOps tool for this module.

You write every file on your own machine, in a new, empty folder. `kubectl` has Kustomize built in, so you need no other tool. The output in the parts comes from `kubectl` 1.35, which contains Kustomize 5.7.1. Run `kubectl version --client` to see which Kustomize version your `kubectl` contains; a newer one prints the same results for everything in this module.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It has these namespaces and workloads:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | `shuttle`, a client pod with `curl`. Every test request in this module is sent from here |
| `starfleet-staging` | Nothing yet. The staging overlay deploys here |
| `starfleet-production` | Nothing yet. The production overlay deploys here |

There is no `scout` workload in the cluster yet: you build it. The node already holds the `podinfo` images `6.14.0` and `6.15.0`, so the pods start without a download. `podinfo` is a small web application that answers each request with a JSON document that shows its version and a message. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
