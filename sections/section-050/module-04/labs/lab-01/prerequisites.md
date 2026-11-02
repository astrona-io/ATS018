# Prerequisites

- `kubectl` 1.35 and the `kubectl-argo-rollouts` plugin 1.10.0 on your `PATH`.
- The Argo Rollouts 1.10.0 controller with the Gateway API plugin v0.17.0, Envoy Gateway, and a small Prometheus (kube-prometheus-stack 92.3.0). The lab installs them.
- The canary Rollout `scout` without steps, the Services `scout` and `scout-canary`, the Gateway `scout-gateway`, the HTTPRoute `scout-route`, a PodMonitor and the `shuttle` pod. The lab creates them. `shuttle` sends requests to the Gateway and has its address in the variable `GATEWAY`.
