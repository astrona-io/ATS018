# Prerequisites

- `kubectl` 1.35 and the `kubectl-argo-rollouts` plugin 1.10.0 on your `PATH`.
- The Argo Rollouts 1.10.0 controller in the namespace `argo-rollouts`. The lab installs it.
- The Deployment `scout` (podinfo 6.14.0, 5 replicas), its Service and the `shuttle` client pod in `starfleet`. The lab creates them.
