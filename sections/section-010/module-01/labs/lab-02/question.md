# Question

Solve this question on: `terminal`

The `starfleet` team needs a staging deployment of `scout`. The folder `~/resources/scout` has a finished `base` and an overlay `overlays/staging` that only includes the base. Nothing is deployed in `starfleet-staging` yet.

Complete the overlay in `~/resources/scout/overlays/staging` and apply it with `kubectl apply -k`. Keep the files in `base` unchanged. Do not change the cluster with `kubectl edit` or `kubectl patch`, and do not write the ConfigMap by hand.

When you finish, these must be true:

- The overlay targets the namespace `starfleet-staging` and uses the existing `../../base`.
- The Deployment `scout` runs the image `ghcr.io/stefanprodan/podinfo:6.15.0` with 1 ready replica.
- A `configMapGenerator` creates a ConfigMap named `scout-settings-<hash>` with `PODINFO_UI_MESSAGE=overlay-staging`. Keep the hash suffix.
- A patch adds an `envFrom` reference to `scout-settings` to the `scout` container.
- `kubectl diff -k` on the overlay shows no difference from the cluster.
- A request from the `shuttle` pod to `http://scout.starfleet-staging/` returns version `6.15.0` and the message `overlay-staging`.

Check your work with `astrona submit`.
