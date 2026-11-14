# Question

Solve this question on: `terminal`

## Scenario

Three independent OpenTofu working
directories need review and repair. Each directory under `~/resources/tofu`
has real local state. Keep every original Deployment and its state identity.
Allow 35 minutes. The `shuttle` request client runs in `starfleet`.

## Tasks

1. **Apply a pending change in `scale`.** The configuration for
   `kubernetes_deployment.scout` in `starfleet-staging` already requests two
   replicas, but the applied Deployment has one. Review and apply the update.
   Keep its existing `kubernetes_service.scout` unchanged.
2. **Add a resource in `expose`.** Keep `kubernetes_deployment.probe` in `outpost`
   at one replica. Add `kubernetes_service.probe`, named `probe` in `outpost`.
   Read its selector from the Deployment's pod labels (`app = "probe"`).
   Use `ClusterIP`, port `80` and target port `9898`.
3. **Repair live drift in `drift`.** The configuration and recorded state for
   `kubernetes_deployment.scout` in `starfleet-production` request two replicas.
   A manual change left one live replica. Restore two through OpenTofu, keeping
   its existing `kubernetes_service.scout` unchanged.
4. **Retain all three reviews.** In each directory, initialize and save
   `change.plan` before applying. Save its human-readable, color-free display
   as `plan.txt` in the same directory. The `scale` and `drift` plans must show
   in-place updates from one replica to two; the `expose` plan must create only
   the Service and leave the Deployment unchanged.
5. **Prove all three results.** Each directory must own its Deployment and
   Service in state and produce a fresh plan with no changes. Keep podinfo
   `6.15.0` and the pod labels. The Services must use `ClusterIP`, selector
   `app = "scout"` for scout or `app = "probe"` for probe, port `80` and target
   port `9898`. All requested replicas must be updated and available. Requests
   from `shuttle` to `http://scout.starfleet-staging/`, `http://probe.outpost/`
   and `http://scout.starfleet-production/` must return version `6.15.0`.
   Keep state files separate. Do not edit state or use `ignore_changes`.
