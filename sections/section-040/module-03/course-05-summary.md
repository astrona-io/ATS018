# Summary

Argo Workflows runs a CI job as a `Workflow` object. The Workflow controller turns every template that runs a container into one pod, with a `main` container for your command and a `wait` container, the executor, that reports the result. A DAG template orders the tasks with `depends`: tasks without a dependency between them run at the same time, and a task that depends on a failed task is `Omitted`. Data moves between tasks as parameters, as output parameters read from a file, and as files on a volume that `volumeClaimTemplates` creates for one run.

A `WorkflowTemplate` holds the graph once. A `Workflow` refers to it with `workflowTemplateRef` and gives only the arguments that change. The executor in each pod needs a ServiceAccount that may create `workflowtaskresults`. Without it the run ends in `Error` even when the command itself works.

Reading a failure always follows the same path. The Workflow phase and message come first. The `status.nodes` list comes second, and the node with the phase `Failed` or `Error` is the one to open. The pod log of that node comes last. `Failed` means a container exited with a non-zero code, `Error` means the controller or the executor could not do its work, and `Omitted` is only a consequence.

Argo Events connects the outside world to the Workflow. An `EventSource` of type `webhook` receives the HTTP request from Git, an `EventBus` carries the event, and a `Sensor` filters it and runs a trigger that creates a Workflow. The Sensor uses its own ServiceAccount, which needs a Role in the namespace of the Workflow. A one-pod JetStream bus needs a stream with one replica.

For readers who know Tekton: a Workflow is like a `PipelineRun`, a `WorkflowTemplate` is like a `Pipeline`, a DAG task with `depends` is like a pipeline task with `runAfter`, `volumeClaimTemplates` is like a workspace, and an `EventSource` with a `Sensor` is like an `EventListener` with a trigger.

Key facts:

- A Workflow with `generateName` is created with `kubectl create`, not `kubectl apply`.
- `kubectl logs -l workflows.argoproj.io/workflow=<name>` reads all pods of one Workflow.
- The phases are `Pending`, `Running`, `Succeeded`, `Failed` and `Error`; a node can also be `Omitted`.
- A Sensor filter reads event data under `body`, for example `body.ref`.

<!-- astrona:playground:destroy -->
