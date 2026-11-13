# Question

Solve this question on: `terminal`

The platform team keeps a Crossplane platform API and its environments in the Git repository `platform-infra`. Crossplane 2.4.3, the `provider-kubernetes` provider and the `function-patch-and-transform` function are already installed and healthy. Nothing from the repository is applied to the cluster yet.

The repository is reachable inside the cluster at `http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git`, branch `main`. From your terminal you reach it at `http://127.0.0.1:3000/starfleet/platform-infra.git` with the user `platform` and the password `starfleet-gitops`. Argo CD 3.5.4 runs in the namespace `argocd` and already has the credentials for this repository. It answers on `https://127.0.0.1:8080`. The user is `admin` and the password is in the Secret `argocd-initial-admin-secret`.

The repository has the `CompositeResourceDefinition` and the `Composition` in `platform/` and one `ScoutEnvironment` each in `environments/staging` and `environments/production`. The files carry sync wave annotations.

Deliver the repository with GitOps, make Argo CD report the real state of the environments, and repair production. Do not apply the repository files with `kubectl apply` by hand.

When you finish, these must be true:

- An Argo CD `Application` named `scout-platform` in the namespace `argocd` syncs the whole repository (path `.`, recursive, branch `main`) to the local cluster. It has automated sync with prune and self-heal on, and the sync option `SkipDryRunOnMissingResource=true`.
- Argo CD has a health check for the kind `ScoutEnvironment` of the group `platform.starfleet.dev`. It reports `Healthy` when the `Ready` condition of the object is `True` and `Degraded` when it is not. A `ScoutEnvironment` in the `Application` shows a health status in Argo CD.
- Production did not become Ready at first. Find the cause by reading the `ScoutEnvironment`, the `Object` resources and the pods, and fix it in Git. The production environment must keep `replicas: 2` and the message `production`.
- Both `ScoutEnvironment` objects are `Ready`, the `Application` is `Synced` and `Healthy`, and requests from `shuttle` to `http://scout.starfleet-staging/` and `http://scout.starfleet-production/` return the version `6.15.0`.

Check your work with `astrona submit`.
