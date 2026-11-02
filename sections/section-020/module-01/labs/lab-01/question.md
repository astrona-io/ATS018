# Question

Solve this question on: `terminal`

The platform team keeps the Kubernetes files for the `scout` application in a private Git repository: `http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git`. The user is `platform` and the password is `starfleet-gitops`. The repository has a Kustomize base and the overlays `overlays/staging` and `overlays/production` on the branch `main`. Argo CD is installed in the namespace `argocd`, but it has no credentials for the repository and no `Application` yet.

Deliver the staging environment from Git with Argo CD. Do not apply the overlay with `kubectl apply -k`, and do not create the namespace `starfleet-staging` yourself.

When you finish, these must be true:

- **Repository access**: Argo CD has a repository Secret in the namespace `argocd` for the repository URL above.
- **Application** `scout-staging` in the namespace `argocd`:
  - It uses the project `default` and syncs the path `overlays/staging` of the branch `main` to the namespace `starfleet-staging` on the same cluster.
  - Automated sync is on, with `prune` and `selfHeal` both `true`.
  - Argo CD creates the namespace `starfleet-staging` for you.
- **Result**:
  - The `Application` is `Synced` and `Healthy`.
  - The Deployment `scout` in `starfleet-staging` is created by Argo CD and runs `ghcr.io/stefanprodan/podinfo:6.15.0`.
  - A request from the `shuttle` pod (namespace `starfleet`) to `http://scout.starfleet-staging/` returns version `6.15.0` and the message `staging`.
  - If someone scales the Deployment by hand, Argo CD puts the replica count back to 1.

Check your work with `astrona submit`.
