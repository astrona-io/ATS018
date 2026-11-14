# Overview: Automate Canary Analysis With Flagger (Playground)

This playground starts a fresh Kubernetes cluster for testing canary releases with Flagger. There is no grading or submission. A canary release sends a growing share of requests to a new version and stops when the measurements are bad. Flagger is the controller that runs this loop.

## What's in the box

The single-node cluster runs Kubernetes 1.35.8. Istio 1.30.7 is a service mesh: a sidecar proxy (Envoy) next to every pod routes the requests, and a `VirtualService` sets the weight between destinations. Istio's Prometheus add-on collects request metrics from those proxies. Flagger 1.45.0 reads that Prometheus and edits the `VirtualService` weights.

| Namespace | What is in it |
| --- | --- |
| `istio-system` | `istiod`, Istio's Prometheus and the Flagger controller |
| `starfleet` | The `scout` Deployment (podinfo 6.14.0), its Service, `shuttle` and `flagger-loadtester` |

The `flagger-loadtester` is a small service that runs a load tool (`hey`) when Flagger calls its webhook. A webhook is an HTTP request that a controller sends to another service at a defined point of the analysis. No `Canary` exists yet.

## Helpers

Paste this function into each new terminal. It prints the version and message that the `scout` Service returns to `shuttle`.

```sh
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -s http://scout.starfleet/ | grep -E '"(version|message)"'
}
```

If you run more than one cluster, other tools can switch your `kubectl` context. Export a kubeconfig for this cluster only: `kind get kubeconfig --name astro-ats-018-playground-080-01 > kubeconfig-flagger` and `export KUBECONFIG=$PWD/kubeconfig-flagger`.

## Practice tasks

- Create a `Canary` for `scout`. List the Deployments, Services and Istio objects Flagger generates and read the weights in the `VirtualService`.
- Change the image to 6.15.0 and follow the `Canary` status until it reports `Succeeded`.
- Deploy podinfo with `--random-error` and read the event that stops the analysis. Prove the primary pods keep serving.
- Find the `no values found` event in a canary and explain why Flagger halts instead of promoting.
