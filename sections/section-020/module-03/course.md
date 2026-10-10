# Diagnose Sync And Health Failures In Argo CD

An `Application` that is not `Synced` and `Healthy` can be broken at four different stages: Argo CD could not fetch the source, could not render it, could not apply it, or applied it and the result does not work. Each stage reports in a different place and needs a different fix. Guessing wastes time; reading the right field first does not.

This module gives you four broken applications at once, one per stage, and a method to tell them apart. It also covers two tools that prevent failures rather than fix them: sync waves and hooks, which order the objects of one sync, and `ignoreDifferences`, which stops Argo CD from fighting another controller over a field.

Keep one sentence in mind for this module: **find the stage first, then fix the cause in the place it lives.** A wrong path is fixed in the `Application`, a rejected manifest and a bad image are fixed in Git, and a field that another controller owns is ignored, not reverted.

The module has four parts. **Where Argo CD Reports A Problem** maps the status fields to the stages and diagnoses fetch and render failures (`ComparisonError`). **Sync Failures, Waves And Hooks** reads a manifest that the API server rejects, unsticks an automated retry, and orders a sync with a `PreSync` hook and a sync wave. **Permanent Drift And ignoreDifferences** stops an application from fighting a HorizontalPodAutoscaler. **Health Failures** reads a `Degraded` application down to the pod event and repairs it through Git.

## Learning objectives

After this module you can:

- Read the sync result and the per-object messages of a failed sync with `argocd app get`.
- Diagnose a `ComparisonError` caused by a wrong repository URL, revision or path.
- Order dependent objects with sync waves and run a `PreSync` hook Job.
- Find why an `Application` stays `OutOfSync` with `argocd app diff`, and ignore a field another controller changes with `ignoreDifferences`.
- Recover a `Degraded` `Application` by fixing the Git repository instead of the cluster.

## Before you start

You need to know the `Application` resource (`source`, `destination`, `syncPolicy` with `automated`, `prune` and `selfHeal`), the difference between sync status and health status, and the commands `argocd app get` and `argocd app diff`. You also need `git` and the `argocd` command-line tool version 3.5.

Your playground is a single-node `kind` cluster running Kubernetes 1.35 with Argo CD 3.5.4 in `argocd`, reachable on `https://127.0.0.1:8080` (user `admin`, password in the Secret `argocd-initial-admin-secret`), and metrics-server, which reports pod CPU use to the HorizontalPodAutoscaler. The private repository `http://gitea-http.gitea.svc:3000/starfleet/scout-faults.git` has one folder per application; from your machine it is `http://127.0.0.1:3000/starfleet/scout-faults.git`, user `platform`, password `starfleet-gitops`. Argo CD already has credentials for it.

Four applications exist, each with automated sync, prune, self-heal and `CreateNamespace=true`, and each **broken on purpose**:

| Application | Folder | Namespace |
| --- | --- | --- |
| `scout-path` | the `Application` says `paths`, the folder is `path` | `starfleet-path` |
| `scout-reject` | `reject` | `starfleet-reject` |
| `scout-hpa` | `hpa` | `starfleet-hpa` |
| `scout-image` | `image` | `starfleet-image` |

Finding out what is wrong with each is the subject of this module, so read their status before you read their files. `kubectl` already points at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
