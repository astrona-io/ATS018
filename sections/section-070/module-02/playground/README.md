# Gate A Blue/Green Release With Analysis — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-070-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with Argo Rollouts
1.10.0, Prometheus Operator and Prometheus from a trimmed
kube-prometheus-stack 92.3.0 chart. The two-replica `scout` Rollout starts
on podinfo 6.15.0 with active and preview Services. `shuttle` sends steady
requests to both, and a PodMonitor preserves each pod's template hash.
No AnalysisTemplate or AnalysisRun exists. Nothing to submit.

Use kubectl 1.35.8 and kubectl-argo-rollouts 1.10.0 on the host. Bootstrap
scripts run with macOS-compatible bash and need outbound internet for the
pinned controller manifest and chart. Helm state stays under `~/.astrona`.
Prometheus is forwarded to host port 9090. The starting message is `stable`;
new configuration messages distinguish releases of the same image.

## Run it

```sh
astrona run -c sections/section-070/module-02/playground --trust
astrona destroy ats-018-playground-070-02
```

Run from the course root. Destroy takes the environment name. Initialization
creates the namespace and client before the Rollout because Astrona runs
initialization scripts before its manifest stage.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, images, initialization, forwarding and readiness checks |
| `bootstrap/01-install-argo-rollouts.sh` | Installs Argo Rollouts and waits for its controller |
| `bootstrap/02-install-prometheus.sh` | Installs the trimmed metrics stack |
| `bootstrap/kps-values.yaml` | Disables unused components and limits Prometheus memory |
| `bootstrap/03-start-scout.sh` | Creates the starting workloads and checks release readiness |
| `manifests/lab-start.yaml` | Namespace and steady request client |
| `manifests/scout.yaml` | Rollout, Services and PodMonitor |
| `docs/overview.md` | Environment contents, helpers and practice tasks |
