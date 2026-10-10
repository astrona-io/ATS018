# Summary

Argo CD keeps a cluster equal to a Git repository. One `Application` object says what to render and where to apply it, and two separate statuses say whether the cluster matches Git and whether it works.

## What you learned

GitOps keeps the desired state in Git and lets a controller in the cluster pull it and reconcile it continuously. Argo CD splits that work over components: the repo server clones and renders, the application controller compares, applies and checks health, the API server serves the web page and the `argocd` tool, and Redis caches. Errors about Git and rendering come from the repo server; errors about applying objects come from the application controller.

An `Application` lives in the `argocd` namespace. Its `source` names a repository, a revision and a path, or a chart and a chart version; its `destination` names a cluster and a namespace. A private repository needs a Secret with the label `argocd.argoproj.io/secret-type: repository` and a `url` that matches `repoURL`. Without it, the application shows a `ComparisonError` and the sync status `Unknown`. A missing destination namespace fails the sync unless `CreateNamespace=true` is set.

Sync status (`Synced`, `OutOfSync`, `Unknown`) compares Git with the cluster. Health status (`Healthy`, `Progressing`, `Degraded`, `Missing`) says whether the objects work. `automated` syncs new commits, `selfHeal` reverts manual changes in the cluster, and `prune` deletes objects that left Git. An application can be `Synced` and `Degraded` at the same time, for example after a commit with an image tag that does not exist, and the fix is always another commit. Since Argo CD 3.0, per-object health is shown by `argocd app get`, not stored in the `Application` object, and objects are tracked by the `argocd.argoproj.io/tracking-id` annotation.

A Helm chart source uses `chart` and a chart version in `targetRevision`, with values in `helm.valuesObject`, `helm.parameters` or `helm.valueFiles`. Argo CD renders the chart and applies the result; no Helm release is installed. The key facts to remember are these:

- `argocd app get --refresh` compares again at once instead of waiting for the next poll.
- `argocd app diff` shows live state against Git and exits with `1` when they differ.
- `OutOfSync` is a Git-versus-cluster question; `Degraded` is a does-it-work question.
- Change Git, not the cluster.

<!-- astrona:playground:destroy -->
