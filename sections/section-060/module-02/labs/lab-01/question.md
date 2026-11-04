# Question

Solve this question on: `terminal`

## Scenario

The `scout` application in `starfleet` needs a second replica and an internal
Service. Its OpenTofu working directory is `~/resources/tofu/scout` and already
has state for the Deployment. Keep that Deployment and its state identity.

## Tasks

1. **Change the configuration.** Set `kubernetes_deployment.scout` to two replicas.
   Keep its podinfo `6.15.0` image and `app = "scout"` pod labels. Add
   `kubernetes_service.scout`, named `scout` in `starfleet`, with type
   `ClusterIP`, selector `app = "scout"`, port `80` and target port `9898`.
   Read the selector from the Deployment's pod labels.
2. **Save the review before applying.** Initialize the directory. Save a binary
   plan as `~/resources/tofu/scout/change.plan`, and its human-readable,
   color-free display as `~/resources/tofu/scout/plan.txt`. The plan must show
   an in-place Deployment update from one replica to two and a Service creation.
3. **Apply and prove the result.** Apply the reviewed plan. Both resources must
   belong to this directory's state, two updated replicas must be available,
   and a fresh plan must propose no changes. A request from `shuttle` in
   `starfleet` to `http://scout.starfleet/` must return version `6.15.0`.
   Do not hide changes with `ignore_changes` or edit the state by hand.
