# Question

Solve this question on: `terminal`

The private repository `platform-apps` contains three workloads in `apps/scout`, `apps/probe` and `apps/bridge`. Gitea and Argo CD are ready, with repository credentials configured. No Applications exist.

## Tasks

1. Create ApplicationSet `platform-apps` in `argocd` with a Git directory generator for `apps/*` on `main` at `http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git`. Enable Go templates and `missingkey=error`.
2. Use `{{.path.basename}}` for Application names and `{{.path.path}}` for source paths. Use project `default`, destination `starfleet` on this cluster, label `team: starfleet`, and automated sync with prune and self-heal. Verify all three generated Applications and their workloads.
3. Clone `http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-apps.git`. Add `apps/beacon` by copying `apps/probe`, replacing `probe` with `beacon` in its Deployment and Service. Commit and push to `main`, then refresh the ApplicationSet.
4. Verify the fourth Application's owner reference points to this ApplicationSet, its Deployment is ready and `http://beacon/get` responds from `shuttle`. Keep all four Applications and workloads for grading.

Do not create child Applications or workloads manually. Do not replace the Git generator with a list.

Learner work: about 15 minutes. Cluster startup, controller reconciliation and rollouts take additional time.
