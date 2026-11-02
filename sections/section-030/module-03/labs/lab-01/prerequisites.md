# Prerequisites

- `kubectl` 1.35, the `flux` command-line tool and `git`.
- Flux 2.9.6 with the source, kustomize, image reflector and image automation controllers in `flux-system`. The lab installs them.
- Gitea with the repository `starfleet/scout-deploy` and the read-write Secret `scout-git` in `flux-system`. Gitea is reachable at `http://127.0.0.1:3000` from the lab terminal. The user `platform` has the password `starfleet-gitops`.
- The in-cluster registry `registry.registry.svc:5000` with the image `starfleet/scout` at the tags `6.14.0` and `6.15.0`. The lab fills it by copying the podinfo image.
- The `shuttle` client pod in the namespace `starfleet`. Flux already delivers `scout` 6.14.0 to `starfleet`.
