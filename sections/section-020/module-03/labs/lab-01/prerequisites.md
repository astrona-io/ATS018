# Prerequisites

- `kubectl` 1.35, `git` and the `argocd` command-line tool.
- Argo CD 3.5.4 in the namespace `argocd`. The lab installs it.
- A private Git repository `starfleet/scout-faults` in the in-cluster Git server, reachable from your terminal on `http://127.0.0.1:3000` (user `platform`, password `starfleet-gitops`). The lab creates it.
- Three broken `Applications` in `argocd` and the `shuttle` client pod in the namespace `starfleet`. The lab creates them.
