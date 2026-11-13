# Shift Canary Traffic With Argo Rollouts And A Traffic Router — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-070-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with Argo Rollouts
1.10.0 and its Gateway API traffic router plugin v0.17.0, Envoy Gateway and
the Gateway API CRDs from astrona's `gatewayAPI: envoy` addon, and
Prometheus Operator and Prometheus from a trimmed kube-prometheus-stack
92.3.0 chart. The two-replica `scout` Rollout starts on podinfo 6.14.0 with
no canary steps, a stable and a canary Service, a Gateway and an HTTPRoute
(`scout=100`, `scout-canary=0`). `shuttle` sends steady requests to the
Gateway address (environment variable `GATEWAY`). No AnalysisTemplate or
AnalysisRun exists. Nothing to submit.

Use kubectl 1.35.8 and kubectl-argo-rollouts 1.10.0 on the host. Bootstrap
scripts run with macOS-compatible bash and need outbound internet for the
pinned controller manifest, the chart and the plugin binary: the Argo
Rollouts controller downloads the plugin from the GitHub release when it
starts. Prometheus is forwarded to host port 9090. The Gateway ports are
mapped to host ports 28080 and 28443 (the addon default 18080 is often in
use).

## Run it

```sh
astrona run -c sections/section-070/module-03/playground --trust
astrona destroy astro-ats-018-playground-070-03
```

Run from the course root. Destroy takes the environment name that
`astrona run` prints, which has the prefix `astro-`. Initialization creates
the namespace and client before the Rollout because Astrona runs
initialization scripts before its manifest stage. `astrona run` switches the
global kubectl context; use a private kubeconfig from `kind get kubeconfig`
when another cluster must keep its context.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, addon, images, initialization, forwarding and readiness checks |
| `bootstrap/01-install-argo-rollouts.sh` | Installs Argo Rollouts, the plugin ConfigMap and RBAC, and waits for the plugin download |
| `bootstrap/02-install-prometheus.sh` | Installs the trimmed metrics stack |
| `bootstrap/kps-values.yaml` | Disables unused components and limits Prometheus memory |
| `bootstrap/03-start-scout.sh` | Creates the workloads, injects the Gateway address into `shuttle` and checks release readiness |
| `manifests/lab-start.yaml` | Namespaces and steady request client |
| `manifests/scout.yaml` | Rollout, Services, Gateway, HTTPRoute and PodMonitor |
| `docs/overview.md` | Environment contents, helpers and practice tasks |
