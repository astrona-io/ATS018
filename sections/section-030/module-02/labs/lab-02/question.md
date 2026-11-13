# Question

Solve this question on: `terminal`

The private repository `http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git` has three child Application manifests in `argocd-apps`. They deliver `scout`, `probe` and `bridge` from `apps/<name>` into `starfleet`. Repository credentials already exist; no Applications exist.

## Tasks

1. Create parent Application `platform-apps` in `argocd`. Read `argocd-apps` on branch `main`, use project `default`, and deliver to `argocd` on this cluster. Enable automated sync, prune and self-heal. Leave the parent without a cascading deletion finalizer.
2. Confirm that the parent created all three children. Inspect each child's source and Argo CD tracking annotation. Do not apply the children or workloads manually.
3. Check all three children for Synced and Healthy and inspect their ready Deployments. From `shuttle` in `starfleet`, request `http://scout/`, `http://probe/get` and `http://bridge/`. A healthy parent alone does not prove healthy children.

Preserve the Git manifests. Do not substitute an ApplicationSet for the parent.

Learner work: about 15 minutes. Cluster startup, controller reconciliation and rollouts take additional time.
