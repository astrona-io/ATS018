# Prerequisites

- `kubectl` 1.35 and the `kubectl-argo-rollouts` plugin 1.10.0 on your `PATH`.
- The Argo Rollouts 1.10.0 controller in the namespace `argo-rollouts`. The lab installs it.
- The canary Rollout `scout` (5 replicas), its Services `scout` and `scout-canary`, the unfinished AnalysisTemplate `scout-canary-message` and the `shuttle` client pod in `starfleet`. The lab creates them and stops a release of podinfo 6.15.0 at its first pause.
- A place to write the file `/tmp/scout-analysisrun.txt` in the same terminal where you run `kubectl`.
