# Question

Solve this question on: `terminal`

The `starfleet` team must ship the `scout` application to staging and production from one Kustomize source. The source is the folder `~/resources/scout`. It has a `base` folder and two overlays, `staging` and `production`. Nothing is deployed yet. The files contain several faults. Some stop the build with an error. Others build without an error but render the wrong objects, or objects that do not start.

Fix the files in `~/resources/scout` and apply both overlays with `kubectl apply -k`. Do not change the cluster with `kubectl edit` or `kubectl patch`, do not write a ConfigMap by hand, and do not copy the base into the overlays.

When you finish, these must be true:

- **Staging** (namespace `starfleet-staging`):
  - The Deployment `scout` runs the image `ghcr.io/stefanprodan/podinfo:6.15.0` with 1 replica and has the label `environment=staging`.
  - It reads its settings from the ConfigMap that the `configMapGenerator` creates (name `scout-settings-<hash>`).
  - The Service `scout` exists and has the label `app.kubernetes.io/part-of=starfleet` from the base.
  - A request from the `shuttle` pod to `http://scout.starfleet-staging/` returns version `6.15.0` and the message `staging`.
- **Production** (namespace `starfleet-production`):
  - The Deployment `scout` runs the image `ghcr.io/stefanprodan/podinfo:6.14.0` with 3 replicas, all ready, and has the label `environment=production`.
  - The container has a memory request of `64Mi` and a memory limit of `128Mi`.
  - It reads its settings from the generated ConfigMap `scout-settings-<hash>`, which holds the message `production`.
  - The Service `scout` exists and has the label `app.kubernetes.io/part-of=starfleet` from the base.
  - A request from the `shuttle` pod to `http://scout.starfleet-production/` returns version `6.14.0` and the message `production`.

Check your work with `astrona submit`.
