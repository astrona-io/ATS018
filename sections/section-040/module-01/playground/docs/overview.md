# Overview: Reconcile Git Sources With Flux Kustomizations (Playground)

This playground starts Flux, a GitOps controller that makes a Kubernetes
cluster match files in Git. It has no grading. Create sources, apply paths,
and inspect the result.

## What's in the box

- Kubernetes 1.35 and Flux 2.9.6, with source, kustomize, helm and notification controllers in `flux-system`.
- The private `starfleet/scout-deploy` repository, hosted by Gitea as bootstrap plumbing.
- The read-only Secret `scout-readonly` in `flux-system`.
- A shared base, a staging overlay, and a `platform` directory that creates `starfleet-staging`.
- The `shuttle` client in `starfleet`, with podinfo 6.14.0 and 6.15.0 preloaded.

No GitRepository or Flux Kustomization exists yet. A GitRepository fetches
Git and publishes an artifact, a stored copy of its files. A Flux
Kustomization renders and applies a path from that artifact.

## Helpers

Paste these functions in a terminal. `show_delivery` reads the source and
applier status. `ask_scout` sends a request from the client to staging.

```sh
show_delivery() {
  flux get sources git
  flux get kustomizations
}
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging
}
```

## Practice tasks

- Create a source with a wrong branch. Read its Ready condition, then fix the branch.
- Create a namespace Kustomization and make the application depend on it.
- Suspend the application, change its replica count, and resume it. Observe which controller removes the difference.
- Change the source credential reference to a Secret that does not exist. Compare the source and applier messages.
