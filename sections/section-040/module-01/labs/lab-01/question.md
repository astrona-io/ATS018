# Question

Solve this question on: `terminal`

The `scout` application is delivered from the Gitea repository `starfleet/scout-deploy` into the namespace `starfleet-staging`. The Flux objects for it are in the namespace `flux-system`, but nothing is delivered to that namespace: the `GitRepository` named `scout` and the `Kustomization` named `scout` exist and are not working. The repository has the folders `platform` (it creates the namespace `starfleet-staging`), `overlays/staging` (it deploys `scout`) and `overlays/production` (it deploys `scout` for production).

Make Flux deliver the application from Git. Do not apply the `scout` workloads with `kubectl`, and do not suspend any Flux object.

When you finish, these must be true:

- The `GitRepository` `scout` follows the branch `main` of `http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git`, keeps the Secret `scout-readonly`, and is `Ready`.
- A `Kustomization` named `platform` in `flux-system` applies the path `./platform` from that source with `prune: true`.
- The `Kustomization` `scout` applies `./overlays/staging`, keeps `prune: true`, and depends on `platform`.
- Both `Kustomization` objects are `Ready` and not suspended.
- Another `Kustomization` that already exists in `flux-system` was left suspended, and the workload it delivers has drifted from Git. Find it and resume it with `flux resume`. Do not delete it, and do not change Git to match the drift. Every `Kustomization` in `flux-system` must end `Ready` and not suspended, and a request from the `shuttle` pod to that workload's Service must return the message that Git holds.
- The staging message is changed in Git: in `overlays/staging/message.yaml` on the branch `main`, the value of `PODINFO_UI_MESSAGE` is `staging-v2`. Flux applies that commit, and a request from the `shuttle` pod to `http://scout.starfleet-staging/` returns the message `staging-v2`.

Use the user `platform` (password `starfleet-gitops`) to clone and push at `http://127.0.0.1:3000/starfleet/scout-deploy.git`.

Check your work with `astrona submit`.
