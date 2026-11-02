# Prerequisites

- `kubectl` 1.35 and the `kubectl-argo-rollouts` plugin 1.10.0 on your `PATH`.
- The Argo Rollouts 1.10.0 controller and a small Prometheus (kube-prometheus-stack 92.3.0) in the cluster. The lab installs them.
- The canary Rollout `scout` in `starfleet` with 4 replicas, its Service `scout`, a PodMonitor that makes Prometheus scrape every `scout` pod, the AnalysisTemplate `scout-success` and the `shuttle` pod that sends five requests per second to the Service. The lab creates them.
