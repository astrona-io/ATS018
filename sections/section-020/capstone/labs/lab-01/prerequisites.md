# Prerequisites

- `kubectl` 1.35 and `git`.
- Argo CD 3.5.4 in the namespace `argocd`. The lab installs it.
- Two private Git repositories, `starfleet/platform-apps` and `starfleet/outpost-apps`, in the in-cluster Git server. Argo CD already has a credential template for the whole `starfleet` organisation. The Git server is also reachable from your machine at `http://127.0.0.1:3000` (user `platform`, password `starfleet-gitops`). The lab creates all of this.
- The `shuttle` client pod in the namespace `starfleet`, an empty namespace `outpost` and the broken Application `probe`. The lab creates them.
