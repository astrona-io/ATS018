# Overview: Build Tekton Tasks And Pipelines (Playground)

This is a **playground**, not a lab. It starts a cluster with Tekton Pipelines, a Git repository and one broken Task, and then waits. There is no task, no `astrona submit` and no pass or fail. Write Tasks and Pipelines, run them, break them, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- **Tekton Pipelines 1.17.0**: the controller and the admission webhook in `tekton-pipelines`, and the remote resolvers (`cluster`, `git`, `bundles`, `http` and `hub`, all on) in `tekton-pipelines-resolvers`. A Task is a list of steps that run as containers in one pod; a Pipeline is an ordered graph of Tasks.
- The Task **`run-tests`** in `starfleet`. It runs the test script of `scout` and fails on purpose: its step works in the wrong folder.
- A **public Git repository** at `http://gitea-http.gitea.svc:3000/starfleet/scout-app.git` (from your machine: `http://127.0.0.1:3000/starfleet/scout-app.git`). It holds `VERSION` (`6.15.0`), the test script `test.sh`, and a shared Task in `tekton/run-tests.yaml`. To push to it, use the user `platform` with the password `starfleet-gitops`.
- `shuttle`, a client pod with `curl`, in `starfleet`. The node already holds the step images `alpine:3.23` and `alpine/git:2.52.0`.
- Deliberately absent: no Pipeline, no Tekton Triggers and no container registry. Install `tkn` 0.46 on your machine to read runs and logs.

## Helpers

Paste these once in each new terminal. `show_runs` lists the TaskRuns and PipelineRuns in `starfleet`. `show_last_run` prints the status and the logs of the newest PipelineRun. `show_step_log` prints the log of one step container of a TaskRun pod, for example `show_step_log scout-ci-abcde-run-tests test`.

```sh
show_runs() {
  tkn -n starfleet taskrun list
  tkn -n starfleet pipelinerun list
}
show_last_run() {
  tkn -n starfleet pipelinerun describe --last
  tkn -n starfleet pipelinerun logs --last
}
show_step_log() {
  kubectl -n starfleet logs "$1-pod" -c "step-$2"
}
```

## Practice tasks

- Run the broken `run-tests` Task on its own with `tkn task start` and an `emptyDir` workspace. Predict the error before you read the log, then find the same error with `kubectl` only.
- Write a Pipeline that clones `scout-app` and runs `run-tests`, with a PersistentVolumeClaim workspace. Fix the Task so the Pipeline succeeds, and publish the commit ID as a Pipeline result.
- Remove `runAfter` from the test Task and run the Pipeline a few times. Explain why it sometimes fails.
- Put a Task in a namespace of its own and use it from `starfleet` with the cluster resolver. Then load `tekton/run-tests.yaml` with the git resolver, pinned to a commit ID.
- Change `VERSION` to a value that is not a version number, push the change, and read which step fails and why.
