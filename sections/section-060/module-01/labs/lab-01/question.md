# Question

Solve this question on: `terminal`

The `drifter` team runs its tests as Argo Workflows in the namespace `starfleet`. The WorkflowTemplate `run-tests` clones `http://gitea-http.gitea.svc:3000/starfleet/scout-app.git` and runs `test.sh`. The team wants every push to the branch `main` of `scout-app` to run it. Gitea already sends a webhook `POST` for each push to `http://push-webhook-eventsource-svc.argo-events.svc:12000/push`. Nothing answers that address yet. The EventBus `default` and the service account `workflow-submitter` (with permission to create Workflows in `starfleet`) already exist in `argo-events`.

Find out why `run-tests` fails and fix it. Then connect the push to the Workflow with Argo Events. Do not create the Workflow with `kubectl` yourself, and do not remove the clone or the call to `test.sh` from the template.

When you finish, these must be true:

- The WorkflowTemplate `run-tests` still clones `scout-app` and runs `test.sh`, and its container starts in the folder where the repository is cloned.
- The EventSource `push-webhook` in `argo-events` has one webhook event named `push` on port `12000` at the endpoint `/push`, and a Service for that port.
- The Sensor `push-ci` in `argo-events` uses the service account `workflow-submitter`, accepts only events whose `body.ref` is `refs/heads/main`, and creates a Workflow from the WorkflowTemplate `run-tests`. It passes the commit ID `body.after` as the argument `revision`.
- The pods of the EventSource and the Sensor are `Running`.
- After the Sensor is running, you push a new commit to `main` of `scout-app`. The Sensor creates a Workflow for exactly that commit, and the Workflow is `Succeeded`.

Use the user `platform` (password `starfleet-gitops`) to clone and push at `http://127.0.0.1:3000/starfleet/scout-app.git`.

Check your work with `astrona submit`.
