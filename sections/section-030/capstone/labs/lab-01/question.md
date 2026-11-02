# Question

Solve this question on: `terminal`

Flux runs in the namespace `flux-system`. Two deliveries are broken.

**Delivery from Git.** The `scout` application is delivered from the Gitea repository `starfleet/scout-deploy` into the namespace `starfleet-staging`. The `GitRepository` named `scout` and the `Kustomization` named `scout` exist and are not working. The repository has the folders `platform` (it creates the namespace `starfleet-staging`) and `overlays/staging` (it deploys `scout`).

**Helm release.** The `HelmRelease` named `relay` in the namespace `starfleet` installs the podinfo chart from the `OCIRepository` `podinfo`. Its last upgrade failed: the helm controller reports `UpgradeFailed` and the new pods never become ready. The release also has no recovery settings.

Repair both. Do not apply the workloads with `kubectl`, do not suspend any Flux object, do not delete and recreate the `HelmRelease`, and do not change the Deployments or Pods with `kubectl edit` or `kubectl patch`.

When you finish, these must be true:

- The `GitRepository` `scout` follows the branch `main` of `http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git`, keeps the Secret `scout-readonly`, and is `Ready`.
- A `Kustomization` named `platform` in `flux-system` applies the path `./platform` from that source with `prune: true`.
- The `Kustomization` `scout` applies `./overlays/staging`, keeps `prune: true`, and depends on `platform`.
- Both `Kustomization` objects are `Ready` and not suspended.
- In `overlays/staging/message.yaml` on the branch `main`, the value of `PODINFO_UI_MESSAGE` is `staging-v2`. Flux applies that commit, and a request from the `shuttle` pod to `http://scout.starfleet-staging/` returns the message `staging-v2`.
- The `HelmRelease` `relay` is `Ready`, the newest release revision in its history has the status `deployed`, and the Deployment `relay-podinfo` has 1 ready replica. A request from `shuttle` to `http://relay-podinfo.starfleet:9898/` returns version `6.15.0`.
- The `HelmRelease` `relay` has upgrade remediation that rolls back a failed upgrade (`strategy: rollback`), retries at least once (`retries` of 1 or more), and also remediates the last failure (`remediateLastFailure: true`).

Use the user `platform` (password `starfleet-gitops`) to clone and push at `http://127.0.0.1:3000/starfleet/scout-deploy.git`.

Check your work with `astrona submit`.
