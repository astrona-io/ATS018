# Deploy An Application With Argo CD

Applying manifests by hand works until two people change the same cluster, or until nobody remembers which file produced which object. GitOps fixes this with one rule: the Git repository holds the desired state, and a controller in the cluster keeps the live state equal to it. Argo CD is the GitOps controller most platforms run, and it is the one this course teaches in depth.

Argo CD reads a path in a Git repository, renders it with Kustomize or Helm, compares the result with the cluster, and applies the difference. Every application it manages is described by one Kubernetes object, the `Application`. Most of what you will do with Argo CD, in the exam and at work, is writing that object and reading its status.

Keep one sentence in mind for this module: **sync status says whether the cluster matches Git, and health status says whether what runs actually works.** The two are reported separately, by different checks, and an application can be perfectly in sync and still broken.

The module has four parts. **GitOps And The Argo CD Components** explains the GitOps principles and the four Argo CD components that carry them out, and logs you in with the `argocd` command-line tool. **The Application Resource** writes the first `Application`, fixes a private repository it cannot read, and syncs it into a namespace that does not exist yet. **Sync Policy, Drift And Health** turns on automated sync with prune and self-heal, proves a manual change is reverted, and breaks the application in Git to show the difference between `OutOfSync` and `Degraded`. **Helm Charts As A Source** delivers the same service from a Helm chart with values set in the `Application`.

## Learning objectives

After this module you can:

- Create an `Application` that points at a Git repository path, a target revision and a destination namespace.
- Read the sync status and the health status of an `Application` with `argocd app get` and `kubectl`.
- Register a private Git repository with a repository Secret.
- Turn on automated sync with prune and self-heal, and prove that a manual change in the cluster is reverted.
- Tell `OutOfSync` from `Degraded` on the same `Application`, and name which check reports each.
- Deliver a Kustomize overlay and a Helm chart through the `Application` source fields.

## Before you start

You need Kubernetes basics (namespaces, Deployments, Services, Secrets, labels) and the commands `kubectl get`, `kubectl apply` and `kubectl exec`. You also need to know what a Kustomize base and overlay are: a base is a folder of shared manifests, and an overlay is a folder whose `kustomization.yaml` changes the base for one environment. You need `git` on your machine, and the `argocd` command-line tool version 3.5.

Your playground is a single-node `kind` cluster running Kubernetes 1.35 with these parts:

| Part | What it is |
| --- | --- |
| Argo CD 3.5.4 in `argocd` | Installed without high availability. The single sign-on server (Dex) and the notifications controller are scaled to zero to save memory |
| A private Git repository | `http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git` inside the cluster, user `platform`, password `starfleet-gitops`. It holds a Kustomize base for `scout` and the overlays `overlays/staging` and `overlays/production` |
| `shuttle` in `starfleet` | A client pod with `curl`. Every test request is sent from here |

The repository is served by Gitea, a small Git server that runs in the cluster; you only use it through `git`. No `Application` exists yet, Argo CD has no credentials for the repository, and the namespaces `starfleet-staging` and `starfleet-production` do not exist. Two ports on your machine reach into the cluster: `https://127.0.0.1:8080` is the Argo CD API server and web page, and `http://127.0.0.1:3000` is the Git server. `kubectl` already points at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
