# Prerequisites

- `kubectl` 1.35, the `tkn` command-line tool and the `argocd` command-line tool 3.5.
- Tekton Pipelines 1.17.0 in the namespace `tekton-pipelines`. The lab installs it.
- Argo CD 3.5.4 in the namespace `argocd`, with the `Application` `scout`. The lab installs both. The `admin` password is in the Secret `argocd-initial-admin-secret`.
- Gitea with the private repositories `starfleet/scout-app` and `starfleet/scout-deploy`. The lab creates them. The user `platform` has the password `starfleet-gitops`.
- The registry `registry.registry.svc:5000` with the images `starfleet/podinfo:6.14.0`, `6.14.1` and `6.15.0` and `starfleet/scout:6.14.0`.
- The Tasks `fetch-source`, `publish-image` and `update-deploy`, the `shuttle` client pod and the `scout` Deployment in the namespace `starfleet`.
