# Prerequisites

- `kubectl` 1.35, `git` and the `argocd` command-line tool on your `PATH`.
- Crossplane 2.4.3 with `provider-kubernetes` v1.4.1, `function-patch-and-transform` v0.11.2, and a `ClusterProviderConfig` named `default`. The lab installs them.
- Argo CD 3.5.4, and the Git server Gitea with the private repository `starfleet/platform-infra`. The lab installs and seeds them. Argo CD already has a repository Secret for it.
- The namespaces `starfleet`, `starfleet-staging` and `starfleet-production`, and the `shuttle` client pod in `starfleet`.
