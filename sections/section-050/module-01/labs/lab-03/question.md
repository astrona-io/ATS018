# Question

Solve this question on: `terminal`

Pipeline `scout-ci` in `starfleet` should fetch source with the shared Task `tekton-tasks/fetch-source`, then resolve the test Task from `tekton/run-tests.yaml` on branch `main` of `http://gitea-http.gitea.svc:3000/starfleet/scout-app.git`. Both resolver locations are wrong. The source repository is public and already contains valid code and its test Task.

## Tasks

1. Start a PipelineRun with a fresh `shared` workspace using a volumeClaimTemplate. Inspect its failure and the resolver parameters on Pipeline `scout-ci`.
2. Repair the cluster and Git Task references on the Pipeline. Keep the two Tasks, their order, workspace bindings and result expressions. Do not copy either Task into `starfleet`, replace it with an inline taskSpec, or edit the shared Task or Git repository.
3. Start a fresh run with a new workspace. Retain a successful run with results `version=6.15.0` and `commit` equal to the commit fetched by `fetch-source`.
4. Inspect the test TaskRun's `status.provenance.refSource`. Its entry point must be `tekton/run-tests.yaml`, and its Git digest must match the fetched source commit. A successful local Task is not proof that a resolver was used.

Learner work: about 15 minutes. Cluster startup, controller reconciliation and rollouts take additional time.
