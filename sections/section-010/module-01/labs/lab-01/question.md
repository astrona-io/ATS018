# Question

Solve this question on: `terminal`

The `outpost` team keeps the Kustomize files for the `scout` application in the folder `~/resources/scout`. It has a `base` folder and two overlays, `staging` and `production`. Neither overlay is deployed yet. The files contain faults, so the overlays do not build or do not render what they should.

Fix the files in `~/resources/scout` and apply both overlays with `kubectl apply -k`. Do not change the cluster with `kubectl edit` or `kubectl patch`, and do not copy the base into the overlays.

When you finish, these must be true:

- **Staging** (namespace `starfleet-staging`):
  - The Deployment `scout` runs the image `ghcr.io/stefanprodan/podinfo:6.15.0` with 1 replica and has the label `environment=staging`.
  - It reads its settings from the ConfigMap that the `configMapGenerator` creates (name `scout-settings-<hash>`).
  - A request from the `shuttle` pod to `http://scout.starfleet-staging/` returns version `6.15.0` and the message `staging`.
- **Production** (namespace `starfleet-production`):
  - The Deployment `scout` runs the image `ghcr.io/stefanprodan/podinfo:6.14.0` with 3 replicas and has the label `environment=production`.
  - The container has a memory request of `64Mi` and a memory limit of `128Mi`.
  - A request from the `shuttle` pod to `http://scout.starfleet-production/` returns version `6.14.0`.

Check your work with `astrona submit`.
