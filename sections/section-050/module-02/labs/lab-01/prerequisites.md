# Prerequisites

- `kubectl` 1.35 and the `kubectl-argo-rollouts` plugin 1.10.0 on your `PATH`.
- The Argo Rollouts 1.10.0 controller and a small Prometheus (kube-prometheus-stack 92.3.0) in the cluster. The lab installs them.
- The blue/green Rollout `scout` in `starfleet`, its Services `scout` (active) and `scout-preview`, a PodMonitor that makes Prometheus scrape every `scout` pod, and the `shuttle` pod that sends one request per second to both Services. The lab creates them.
