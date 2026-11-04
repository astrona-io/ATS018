# Overview: Run CI Workflows With Argo Workflows (Playground)

This is a **playground**, not a lab. It starts a cluster with Argo Workflows, Argo Events and a Git repository, and then waits. There is no task, no `astrona submit` and no pass or fail. Write Workflows, break them, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- **Argo Workflows v4.1.6** in `starfleet`. The controller only watches that namespace. The web server is not installed, so you work with `kubectl` and the `argo` command-line tool.
- **`argo` v4.1.6** in `~/.astrona/bin`, unless you already have an `argo`. It talks to the Kubernetes API through your kubeconfig. If your shell does not find it, run `export PATH="$HOME/.astrona/bin:$PATH"`.
- **Argo Events v1.9.11** in `argo-events`, with an `EventBus` named `default` (one NATS JetStream pod).
- A public Git repository `starfleet/scout-app` at `http://gitea-http.gitea.svc:3000` (from your machine: `http://127.0.0.1:3000`), user `platform`, password `starfleet-gitops`. It has a `VERSION` file (`6.15.0`) and a script `test.sh` that checks it. A push webhook on the repository sends events to `http://push-webhook-eventsource-svc.argo-events.svc:12000/push`.
- In `starfleet`: `shuttle` (a client pod with `curl`), the ServiceAccount `workflow-runner` (it may create `workflowtaskresults`, which the Workflow executor needs), and the `WorkflowTemplate` `run-tests`.
- Deliberately absent: no `Workflow`, no `EventSource` and no `Sensor`. The `run-tests` template has a wrong `workingDir`.

## Helpers

Paste these once in each new terminal. `show_workflows` lists the Workflows with their phase. `show_nodes` prints the nodes of the newest Workflow with their phase and message. `show_failed_logs` prints the logs of the pods of the newest Workflow.

```sh
show_workflows() {
  kubectl -n starfleet get workflows
}
show_nodes() {
  NAME=$(kubectl -n starfleet get workflows --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
  kubectl -n starfleet get workflow "$NAME" -o jsonpath='{range .status.nodes.*}{.displayName}{"\t"}{.phase}{"\t"}{.message}{"\n"}{end}'
}
show_failed_logs() {
  NAME=$(kubectl -n starfleet get workflows --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
  kubectl -n starfleet logs -l workflows.argoproj.io/workflow="$NAME" --all-containers --prefix
}
```

## Practice tasks

- Submit a Workflow that has a DAG of four tasks, where two tasks run in parallel after the first. Pass one output parameter to the last task.
- Move it into a `WorkflowTemplate` and start two runs with different `revision` arguments.
- Run a Workflow with the `default` ServiceAccount, read the error, and fix it without changing the Workflow's steps.
- Fix `run-tests` so the tests pass.
- Read a failed run with `argo list`, `argo get` and `argo logs`. Start a new one with `argo submit --from workflowtemplate/run-tests`, then delete the failed run with `argo delete`.
- Copy a step into the same group of a `steps` list, then write the same order as a DAG.
- Create an `EventSource` and a `Sensor` that start `run-tests` for a push to `main`. Push a new `VERSION` and prove that a Workflow starts with the commit ID as its `revision`.
- Push to another branch and show that no Workflow starts.
