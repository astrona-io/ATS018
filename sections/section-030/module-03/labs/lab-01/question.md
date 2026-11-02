# Question

Solve this question on: `terminal`

Flux delivers the `scout` application from the Gitea repository `starfleet/scout-deploy` (folder `apps/scout`) and it runs version `6.14.0`. The in-cluster registry `registry.registry.svc:5000` also holds the image `starfleet/scout` at the tag `6.15.0`. The registry speaks plain HTTP. The `GitRepository` `scout-deploy` in `flux-system` already has a credential that can push.

Set up Flux image automation so that Flux itself finds the newest tag and commits it to Git. Do not edit the image tag by hand in Git and do not change the Deployment with `kubectl`.

When you finish, these must be true:

- An `ImageRepository` named `scout` in `flux-system` scans `registry.registry.svc:5000/starfleet/scout` and is `Ready`.
- An `ImagePolicy` named `scout` reads that `ImageRepository`, uses a semver range that allows `6.14.0` and above, is `Ready` and selects `6.15.0`.
- The `newTag` line in `apps/scout/kustomization.yaml` carries the setter marker for the policy `flux-system:scout:tag`.
- An `ImageUpdateAutomation` named `scout` in `flux-system` uses `strategy: Setters` on the path `./apps/scout`, pushes to the branch `main` of the `GitRepository` `scout-deploy`, uses the commit author name `fluxcdbot`, is `Ready` and has pushed a commit.
- On the branch `main`, `newTag` is `6.15.0`, and the newest commit of that file is by the author `fluxcdbot`. Flux applies that commit, and a request from the `shuttle` pod to `http://scout.starfleet.svc/` returns version `6.15.0`.

Use the user `platform` (password `starfleet-gitops`) to clone and push at `http://127.0.0.1:3000/starfleet/scout-deploy.git`.

Check your work with `astrona submit`.
