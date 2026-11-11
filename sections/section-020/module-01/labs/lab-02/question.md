# Question

Solve this question on: `terminal`

Argo CD is installed. No Application or Helm release exists for `scout-preview`.

## Tasks

1. Create Application `scout-preview` in `argocd`. Use chart `podinfo` version `6.15.0` from `ghcr.io/stefanprodan/charts` and release name `scout`.
2. Set `valuesObject` to use `fullnameOverride: scout`, two replicas and `ui.message: preview`. Deliver into `starfleet-preview` on this cluster with automated sync, prune, self-heal and `CreateNamespace=true`.
3. Wait for Synced and Healthy. Inspect the Deployment's Argo CD tracking annotation and confirm that `http://scout.starfleet-preview:9898/` returns version `6.15.0` and message `preview` from `shuttle` in `starfleet`.

Use the Application to deliver the chart. Do not install it with Helm or apply its rendered workloads yourself.

Learner work: about 15 minutes. Cluster startup, controller reconciliation and rollouts take additional time.
