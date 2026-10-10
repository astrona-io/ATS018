# Summary

Tekton runs CI work as Kubernetes objects. Every definition is a custom resource you can apply, and every run is a custom resource with a status you can read with `tkn` or with `kubectl`.

## What you learned

A Task is a list of steps, and each step is a container. A TaskRun runs a Task once: the Tekton controller creates one pod for it, with one container per step named `step-<step name>`, and Tekton's entrypoint program makes the steps run one after the other. Params are the named inputs of a Task, and `$(params.<name>)` puts their values into the steps before the pod starts. Results are small named outputs: a step writes them to `$(results.<name>.path)`, and Tekton stores them in the status of the run.

A workspace is a volume that Tekton mounts into the steps, at `$(workspaces.<name>.path)`. A Pipeline orders Tasks with `runAfter` and with result references such as `$(tasks.fetch-source.results.version)`, and binds its own workspaces to the workspaces of its Tasks. Each Task in a Pipeline runs in its own pod, so files can only pass between Tasks through a PersistentVolumeClaim. A `volumeClaimTemplate` in the PipelineRun creates a fresh claim for every run and removes it with the run.

A failure is read from the top down. The PipelineRun message counts the failed and skipped Tasks. The failed TaskRun names the step and its exit code, with a reason such as `StepFailed`. The container log of that step holds the error itself. A run with a broken definition, such as a missing workspace binding or a Task a resolver cannot find, fails on the PipelineRun with a reason such as `InvalidWorkspaceBindings` or `CouldntGetTask`, and no pod is created.

Resolvers fetch a Task from somewhere other than the namespace of the run. All five resolvers (`cluster`, `git`, `bundles`, `http` and `hub`) are on by default in Tekton Pipelines 1.17. The cluster resolver reads a Task from another namespace, and the git resolver reads a file from a Git repository at a branch, tag or commit. Each fetch leaves a ResolutionRequest, and the TaskRun records the exact source in `status.provenance`. The key facts to remember are these:

- A Task and a Pipeline do nothing until a TaskRun or a PipelineRun starts them.
- Use `kubectl create` for a run that has `generateName`; `kubectl apply` needs a fixed name.
- Two Tasks share files only through a PersistentVolumeClaim workspace.
- A finished run never changes: fix the definition and start a new run.
- The hub resolver defaults to Artifact Hub, because Tekton Hub is shut down.

<!-- astrona:playground:destroy -->
