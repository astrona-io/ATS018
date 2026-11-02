# Question

Solve this question on: `terminal`

The platform team keeps a Crossplane platform API and its environments in the Git repository `platform-infra`. Crossplane 2.4.3, the `provider-kubernetes` provider and the `function-patch-and-transform` function are already installed and healthy. Nothing from the repository is applied to the cluster yet.

The repository is reachable inside the cluster at `http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git`, branch `main`. From your terminal you reach it at `http://127.0.0.1:3000/starfleet/platform-infra.git` with the user `platform` and the password `starfleet-gitops`. Argo CD 3.5.4 runs in the namespace `argocd` and already has the credentials for this repository. It answers on `https://127.0.0.1:8080`. The user is `admin` and the password is in the Secret `argocd-initial-admin-secret`.

The repository has the `CompositeResourceDefinition` and the `Composition` in `platform/` and one `ScoutEnvironment` each in `environments/staging`, `environments/production` and `environments/preview`. The files carry sync wave annotations. The namespaces `starfleet-staging`, `starfleet-production` and `starfleet-preview` exist.

Deliver the repository with GitOps, make Argo CD report the real state of the environments, and repair what is broken. Do not apply the repository files with `kubectl apply` by hand, and do not change the delivered objects with `kubectl edit` or `kubectl patch`.

When you finish, these must be true:

- An Argo CD `Application` named `scout-platform` in the namespace `argocd` syncs the whole repository (path `.`, recursive, branch `main`) to the local cluster. It has automated sync with prune and self-heal on, and the sync option `SkipDryRunOnMissingResource=true`.
- Argo CD has a health check for the kind `ScoutEnvironment` of the group `platform.starfleet.dev`. It reports `Healthy` when the `Ready` condition of the object is `True` and `Degraded` when it is not.
- Every fault in the repository is fixed in Git. The environments keep their values: staging has `replicas: 1` and the message `staging`, production has `replicas: 2` and the message `production`, and preview has `replicas: 1` and the message `preview`. All three run version `6.15.0`.
- All three `ScoutEnvironment` objects are `Ready`, the `Application` is `Synced` and `Healthy`, and a request from `shuttle` to `http://scout.starfleet-staging/`, `http://scout.starfleet-production/` and `http://scout.starfleet-preview/` returns the version `6.15.0` and the message of that environment.

A `Ready` condition does not prove that requests reach the pods. Check with a request from `shuttle`.

Check your work with `astrona submit`.
