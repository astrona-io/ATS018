# Question

Solve this question on: `terminal`

Argo CD runs in the namespace `argocd` and can read two private Git repositories on `http://gitea-http.gitea.svc:3000`:

- `starfleet/platform-apps` (branch `main`) has the folders `apps/probe`, `apps/scout`, `envs/staging` and `envs/production`.
- `starfleet/outpost-apps` (branch `main`) holds the folder `scout`, the service of the `outpost` team.

From your machine, Git is also available at `http://127.0.0.1:3000` (user `platform`, password `starfleet-gitops`). The `drifter` team reports that the Application `probe` never became healthy. It deploys `apps/probe` of `platform-apps` into the namespace `starfleet`. Besides `probe` and the `default` project, there is no other `Application`, `ApplicationSet` or `AppProject`. Do not apply any overlay with `kubectl apply -k`, and do not create the namespaces `starfleet-staging` and `starfleet-production` yourself. The namespace `outpost` already exists.

Finish the delivery. When you finish, these must be true:

- **Application** `probe` in `argocd`:
  - The fault is repaired in Git on `main`, not on the cluster. Keep the Application, its repository, path and destination.
  - It has automated sync with `prune` and `selfHeal`.
  - It is `Synced` and `Healthy`, and a request from the `shuttle` pod (namespace `starfleet`) to `http://probe.starfleet/get` returns a response.
- **Project** `outpost` (an `AppProject` in `argocd`):
  - Its applications may use only the repository `http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git`.
  - Its applications may deploy only to the namespace `outpost` on the same cluster (`https://kubernetes.default.svc`).
  - It allows only the namespaced kinds `Deployment` (group `apps`) and `Service`, and no cluster-scoped resource.
- **ApplicationSet** `scout-envs` in `argocd`:
  - It uses a list generator with the values `staging` and `production` to generate the `Applications` `scout-staging` and `scout-production`.
  - Each one uses the project `default`, syncs `envs/<env>` of `platform-apps` to the namespace `starfleet-<env>`, has automated sync with `prune` and `selfHeal`, and creates its namespace.
  - Both are `Synced` and `Healthy`. Staging runs 1 replica and production runs 2. A request from `shuttle` to `http://scout.starfleet-staging/` and to `http://scout.starfleet-production/` returns version `6.15.0`.
- **Application** `outpost-scout` in `argocd`:
  - It uses the project `outpost` and syncs the folder `scout` of `outpost-apps` to the namespace `outpost`, with automated sync and `selfHeal`.
  - It is `Synced` and `Healthy`, and a request from `shuttle` to `http://scout.outpost/` returns a version.

Check your work with `astrona submit`.
