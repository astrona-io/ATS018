# Overview: Automate Image Updates With Flux (Playground)

Flux image automation scans a container registry, picks a tag by a rule and
commits that tag to Git. This playground starts with `scout` 6.14.0 delivered
from Git and no image automation objects, so you create them yourself.

## What's in the box

- Kubernetes 1.35, Flux 2.9.6 and the source, kustomize, notification, image reflector and image automation controllers.
- Gitea with the repository `starfleet/scout-deploy`, forwarded to `127.0.0.1:3000`. The user is `platform` and the password is `starfleet-gitops`.
- An in-cluster registry that holds `starfleet/scout:6.14.0` and `6.15.0`.
- A `GitRepository` and a `Kustomization` named `scout` in `flux-system` that deliver `apps/scout` to `starfleet`.
- A Secret named `scout-git` with a read-write Git credential.
- The `shuttle` client in `starfleet`.

No `ImageRepository`, `ImagePolicy` or `ImageUpdateAutomation` exists yet. The
Helm and source-watcher controllers are switched off to save memory.

## Helpers

Paste these functions in a terminal. `show_image_automation` prints the status
of every object in the flow. `ask_scout` reads the version from the client pod.

```sh
show_image_automation() {
  flux get image repository -n flux-system
  flux get image policy -n flux-system
  flux get image update -n flux-system
  flux get kustomizations -n flux-system
}
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet.svc
}
```

## Practice tasks

- Create an `ImageRepository` and an `ImagePolicy` that select the newest `scout` version.
- Add a setter marker to `apps/scout/kustomization.yaml` and push it.
- Create an `ImageUpdateAutomation` and find its commit in `git log`.
- Publish a new tag with a `crane tag` Job and follow it to the Deployment.
- Change the policy range so it ignores the newest tag and watch the automation stop.
