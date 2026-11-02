# Prerequisites

- `kubectl` 1.35, the `flux` command-line tool and `git`.
- Flux 2.9.6 (source, kustomize, helm and notification controllers) in the namespace `flux-system`. The lab installs it.
- Gitea with the repository `starfleet/scout-deploy` (branch `main`) and the read-only Secret `scout-readonly` in `flux-system`. The lab creates them. Gitea is reachable at `http://127.0.0.1:3000` from the lab terminal. The user `platform` has the password `starfleet-gitops` and can push.
- The `shuttle` client pod, the `OCIRepository` `podinfo` and the failed `HelmRelease` `relay` in the namespace `starfleet`. The lab creates them. The cluster needs access to `ghcr.io` to fetch the chart.
