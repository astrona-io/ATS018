# Question

Solve this question on: `terminal`

The `scout` application in the namespace `starfleet` runs as a plain Deployment with 5 replicas of podinfo `6.14.0`. The `outpost` team wants every new version to reach 20 percent and 60 percent of the pods first, with a person approving each step. The Argo Rollouts controller is already installed.

Replace the Deployment with an Argo Rollouts `Rollout` named `scout`, then release podinfo `6.15.0` through its steps.

When you finish, these must be true:

- The Deployment `scout` no longer exists in `starfleet`. The Rollout `scout` has 5 replicas, selects the pods with the label `app=scout` and keeps the existing Service `scout` working.
- The Rollout uses the `canary` strategy. Its first step is `setWeight: 20`, and the step after it is a `pause` with no duration (it waits until a person promotes it). `maxUnavailable` is `0`.
- The Rollout started on `6.14.0` and was then updated to the image `ghcr.io/stefanprodan/podinfo:6.15.0`, so the release moved through its canary steps.
- The Rollout is `Healthy`, its stable ReplicaSet is the `6.15.0` one, and 5 pods are ready.
- A request from the `shuttle` pod to `http://scout.starfleet/` returns version `6.15.0`.

Do not delete the Service. Do not skip the release by creating the Rollout directly on `6.15.0`, and do not use `promote --full`.

Check your work with `astrona submit`.
