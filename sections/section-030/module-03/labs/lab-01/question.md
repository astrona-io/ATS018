# Question

Solve this question on: `terminal`

Three Argo CD `Applications` in the namespace `argocd` deliver `scout` from the private Git repository `starfleet/scout-faults` (branch `main`). None of them works:

- `scout-path` deploys to `starfleet-path`.
- `scout-reject` deploys to `starfleet-reject`.
- `scout-image` deploys to `starfleet-image`.

Find the fault of each application and fix it. The repository is reachable from your terminal at `http://127.0.0.1:3000/starfleet/scout-faults.git` (user `platform`, password `starfleet-gitops`). Fix a problem in Git when the faulty file is in Git, and fix it in the `Application` when the fault is in the `Application`. Do not delete an `Application`, do not turn off automated sync, `prune` or `selfHeal`, and do not change the `repoURL`, the destination or the folder of `scout-reject` and `scout-image`.

When you finish, these must be true for each of the three applications:

- The `Application` is `Synced` and `Healthy`.
- The Deployment `scout` in its namespace is created by Argo CD from Git.
- A request from the `shuttle` pod (namespace `starfleet`) to `http://scout.<namespace>/` returns version `6.15.0`.
- For `scout-reject` and `scout-image`, the faulty file in Git is fixed on the branch `main`.

Check your work with `astrona submit`.
