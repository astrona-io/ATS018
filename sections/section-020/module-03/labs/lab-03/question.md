# Question

Solve this question on: `terminal`

Application `scout-path` delivers the `path` directory of `http://gitea-http.gitea.svc:3000/starfleet/scout-faults.git` into `starfleet-path`. Its Deployment and Service are healthy. The repository has no hook or settings ConfigMap.

## Tasks

1. Clone `http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-faults.git`. Add Job `scout-migrate` in `path/migrate.yaml`, using `busybox:1.37` to print `migrating the scout schema`, sleep five seconds, then print `done`. Set `backoffLimit: 0` and `restartPolicy: Never`.
2. Mark the Job as an Argo CD `PreSync` hook with deletion policy `BeforeHookCreation`. Add ConfigMap `scout-settings` in `path/settings.yaml`, with sync wave `"-1"` and `PODINFO_UI_MESSAGE: waves` in its data. The existing workload stays in wave `0`.
3. Include both files in `path/kustomization.yaml`, commit and push to `main`. Refresh the Application and wait for Synced and Healthy.
4. Inspect the successful PreSync result in the Application's operation state, the completed Job and its logs, and the ConfigMap's wave annotation. Keep the completed Job for grading.

Deliver the new resources through Git. Do not apply or run the Job manually. The ConfigMap demonstrates ordering; this task does not wire it into the application environment.

Learner work: about 15 minutes. Cluster startup, controller reconciliation and rollouts take additional time.
