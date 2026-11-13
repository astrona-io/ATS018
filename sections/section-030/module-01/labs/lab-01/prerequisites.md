# Prerequisites

- `kubectl` 1.35 and the `argocd` command-line tool (optional: `kubectl` alone is enough).
- Argo CD 3.5.4 in the namespace `argocd`. The lab installs it.
- A private Git repository `starfleet/scout-deploy` in the in-cluster Git server, with the Kustomize base and the overlays `staging` and `production`. The lab creates it.
- The `shuttle` client pod in the namespace `starfleet`. The lab creates it. The namespaces `starfleet-staging` and `starfleet-production` do not exist yet.
