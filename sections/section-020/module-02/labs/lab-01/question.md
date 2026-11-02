# Question

Solve this question on: `terminal`

Argo CD runs in the namespace `argocd` and can already read two private Git repositories on `http://gitea-http.gitea.svc:3000`:

- `starfleet/platform-apps` (branch `main`) has the folders `envs/staging` and `envs/production`. Each folder is a Kustomize overlay for `scout`.
- `starfleet/outpost-apps` (branch `main`) holds the folder `scout`, the service of the `outpost` team.

There is no `Application`, no `ApplicationSet` and no `AppProject` besides `default`. Do not apply any overlay with `kubectl apply -k`, and do not create the namespaces `starfleet-staging` and `starfleet-production` yourself. The namespace `outpost` already exists.

Set up delivery. When you finish, these must be true:

- **Project** `outpost` (an `AppProject` in `argocd`):
  - Its applications may use only the repository `http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git`.
  - Its applications may deploy only to the namespace `outpost` on the same cluster (`https://kubernetes.default.svc`).
  - It allows only the namespaced kinds `Deployment` (group `apps`) and `Service`, and no cluster-scoped resource.
- **ApplicationSet** `scout-envs` in `argocd`:
  - It uses a list generator with the values `staging` and `production` to generate the `Applications` `scout-staging` and `scout-production`.
  - Each one uses the project `default`, syncs `envs/<env>` of `platform-apps` to the namespace `starfleet-<env>`, has automated sync with `prune` and `selfHeal`, and creates its namespace.
  - Both are `Synced` and `Healthy`. Staging runs 1 replica and production runs 2. A request from the `shuttle` pod (namespace `starfleet`) to `http://scout.starfleet-staging/` and to `http://scout.starfleet-production/` returns version `6.15.0`.
- **Application** `outpost-scout` in `argocd`:
  - It uses the project `outpost` and syncs the folder `scout` of `outpost-apps` to the namespace `outpost`, with automated sync and `selfHeal`.
  - It is `Synced` and `Healthy`, and a request from `shuttle` to `http://scout.outpost/` returns a version.

Check your work with `astrona submit`.
