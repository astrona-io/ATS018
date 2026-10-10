# Hand Off From A Tekton Pipeline To GitOps

A CI pipeline produces a new version, and a GitOps controller delivers it. The two meet in one place: a commit to the GitOps repository that changes the image tag. The pipeline never runs `kubectl apply` against the application. It publishes the image, writes the new tag into Git, and stops. Argo CD sees the commit and rolls out the new version.

This split is the hand-off. It keeps one source of truth for what runs in the cluster, it keeps cluster credentials out of the pipeline, and it gives every release a commit that you can read, review and revert.

Keep one sentence in mind for this module: **the pipeline writes to the registry and to Git, and only Argo CD writes to the cluster.** Every step you build either publishes an image, commits a tag, or starts the pipeline.

The module has four parts. **Publish An Image To The Registry** explains the hand-off and writes a Task that publishes a new image tag. **Commit The New Tag With Git Credentials** writes the Task that changes the tag in the GitOps repository, and gives it credentials through a Secret and a service account. **One Pipeline From Source To Commit** chains the clone, the publish and the commit into one Pipeline and follows its commit until Argo CD serves it. **Start The Pipeline From A Git Push** adds Tekton Triggers and a webhook, so one push to the source repository ends with the new version answering requests.

## Learning objectives

After this module you can:

- Push a newly tagged image to the in-cluster registry from a pipeline Task.
- Update the image tag in a GitOps repository from a pipeline with a Git commit.
- Give a Task Git credentials through a Secret and a service account.
- Start a PipelineRun from a Git push with an `EventListener`, a `TriggerBinding` and a `TriggerTemplate`.
- Prove the full flow from a push to a PipelineRun, a commit and an Argo CD sync of the new version.

## Before you start

You need Kubernetes basics (namespaces, pods, Secrets, ServiceAccounts, Role and ClusterRole bindings) and the commands `kubectl apply`, `kubectl create` and `kubectl exec`. You need to know what a Tekton Task, Pipeline, TaskRun, PipelineRun, param, result and workspace are, and what an Argo CD `Application` with automated sync does. On your machine you need `git`, `tkn` 0.46 and the `argocd` command-line tool 3.5.

Your playground is a single-node `kind` cluster running Kubernetes 1.35 with these parts:

| Part | What it is |
| --- | --- |
| Tekton Pipelines 1.17.0 and Triggers 0.36.4 | The pipeline controller and the Triggers controller, webhook and core interceptors, in `tekton-pipelines` |
| A container registry | `registry.registry.svc:5000` inside the cluster, over plain HTTP. It holds the podinfo base images `starfleet/podinfo:6.14.0`, `6.14.1` and `6.15.0`, and `starfleet/scout:6.14.0` |
| Two private Git repositories | `starfleet/scout-app` (the source, with a `VERSION` file that says `6.14.0`) and `starfleet/scout-deploy` (the GitOps repository: a Deployment, a Service and a `kustomization.yaml` that sets the image tag) at `http://gitea-http.gitea.svc:3000`, user `platform`, password `starfleet-gitops` |
| Argo CD 3.5.4 | The `Application` `scout` syncs `scout-deploy` into `starfleet` with automated sync, prune and self-heal |
| `starfleet` | `scout` (version `6.14.0`), `shuttle` (a client pod with `curl`) and the Task `fetch-source`, which clones a repository and reports its commit ID and `VERSION` |

The Git repositories are served by Gitea, a small Git server in the cluster. Deliberately absent: the pipeline has no Git credentials, there is no `EventListener`, and the source repository has no webhook. Two ports on your machine reach into the cluster: `https://127.0.0.1:8080` is the Argo CD API server, and `http://127.0.0.1:3000` is the Git server. `kubectl` already points at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
