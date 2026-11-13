# Question

Solve this question on: `terminal`

The `drifter` team runs its tests as Argo Workflows in the namespace `starfleet`. Every push to the branch `main` of `http://gitea-http.gitea.svc:3000/starfleet/scout-app.git` must start the WorkflowTemplate `run-tests`, which clones the repository and runs `test.sh`. Gitea sends a webhook `POST` for each push to the EventSource `push-webhook` in `argo-events`. The Sensor `push-ci` should turn each event into a Workflow. The EventSource, the Sensor, the EventBus and the service accounts all exist, and the pods run. The pipeline still does not work.

Find out why and repair it. Fix what is broken; do not replace the pipeline. Do not create Workflows with `kubectl` yourself, do not remove the clone or the call to `test.sh` from the template, and do not give the workflow pods broad rights.

When you finish, these must be true:

- The WorkflowTemplate `run-tests` still clones `scout-app` and runs `test.sh`, and its container starts in the folder where the repository is cloned.
- The Sensor `push-ci` uses the service account `workflow-submitter`, accepts only events whose `body.ref` is `refs/heads/main`, creates a Workflow from the WorkflowTemplate `run-tests`, and passes the ID of the pushed commit (`body.after`) as the first Workflow argument, `revision`.
- The pods of the EventSource `push-webhook` and the Sensor `push-ci` are `Running`.
- The service account `workflow-runner`, which the workflow pods use, can `create` and `patch` `workflowtaskresults` in `starfleet`. It has no wider rights.
- After the Sensor is repaired and running, you push a new commit to `main` of `scout-app`. The Sensor creates a Workflow for exactly that commit, and the Workflow is `Succeeded`.

Use the user `platform` (password `starfleet-gitops`) to clone and push at `http://127.0.0.1:3000/starfleet/scout-app.git`.

Check your work with `astrona submit`.
