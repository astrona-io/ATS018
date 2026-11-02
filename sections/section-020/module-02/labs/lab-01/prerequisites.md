# Prerequisites

- `kubectl` 1.35.
- Argo CD 3.5.4 in the namespace `argocd`. The lab installs it.
- Two private Git repositories, `starfleet/platform-apps` and `starfleet/outpost-apps`, in the in-cluster Git server. Argo CD already has a credential template for the whole `starfleet` organisation. The lab creates all of this.
- The `shuttle` client pod in the namespace `starfleet` and an empty namespace `outpost`. The lab creates them.
