# Run CI Workflows With Argo Workflows

Argo Workflows is a Kubernetes controller that runs a job made of many steps. You describe the job in a `Workflow` object. The Workflow controller reads it and starts one pod for each step, in the order you describe. Argo Events is a second, separate project that listens for outside events, such as a Git push, and starts a Workflow when one arrives.

Together they do the same job as a Tekton pipeline with Tekton Triggers. A push reaches a webhook, a Workflow clones the repository, runs the tests and reports the result. The CNPE exam lets you choose a tool for a CI task, so you need to know both: the objects, the commands that read their status, and the way to find out why a run failed.

Keep one sentence in mind for this module: **a Workflow is a graph of templates, each node of the graph is a pod, and the status of the Workflow tells you which node failed and why.**

The module has six parts. **A Workflow With A DAG** writes a Workflow with a directed acyclic graph (DAG) of tasks, passes a parameter and shared files between them, and shows the pod each task creates. **Reuse A Workflow With A WorkflowTemplate** moves the same graph into a `WorkflowTemplate` and starts runs from it with arguments. **Read A Failed Workflow** breaks runs on purpose and finds each cause with `kubectl`. **Start A Workflow From A Git Push** adds an Argo Events `EventSource`, `EventBus` and `Sensor` so a push to the source repository starts the tests. **Run Workflows With The argo Command-Line Tool** starts, reads, repairs and cleans up runs with `argo`, and runs steps in parallel in a `steps` list.

**Pass A Step Output Through A Checksum Check** adds an ordered step, passes its input and output parameters, and compares its recorded digest with the input.

## Learning objectives

After this module you can:

- Write a `Workflow` with a DAG, task dependencies, input and output parameters and a shared volume.
- Create a `WorkflowTemplate` and start a `Workflow` from it with `workflowTemplateRef` and arguments.
- Give Workflow pods a ServiceAccount with the permission the executor needs.
- Find the failed node of a Workflow and read its pod logs with `kubectl`.
- Start a Workflow from a Git push with an `EventSource`, an `EventBus` and a `Sensor`.
- Start, read and delete runs and update templates with the `argo` command-line tool.
- Run steps in parallel in a `steps` list and explain how a DAG differs.
- Pass a prepared value through ordered steps and verify the checksum recorded as an output parameter.
- Start a run with a namespace parameter and the ServiceAccount that has the rights to create objects there.

## Before you start

You need Kubernetes basics (namespaces, pods, PersistentVolumeClaims, ServiceAccounts, Roles and RoleBindings) and the commands `kubectl apply`, `kubectl get`, `kubectl logs` and `kubectl exec`. You do not need to know any other CI tool.

Your playground is a single-node `kind` cluster running Kubernetes 1.35 with these parts:

| Part | What it is |
| --- | --- |
| Argo Workflows v4.1.6 | The Workflow controller, installed in `starfleet` in namespace mode. It only watches `starfleet`. The Argo Workflows web server is not installed |
| `argo` v4.1.6 | The command-line tool in `~/.astrona/bin`, unless you already have an `argo`. It talks to the Kubernetes API through your kubeconfig |
| Argo Events v1.9.11 | The Events controller manager in `argo-events` |
| An `EventBus` | The object `default` in `argo-events`: one NATS JetStream pod that carries events from event sources to sensors |
| A Git repository | `starfleet/scout-app` in Gitea, a small Git server in the cluster, at `http://gitea-http.gitea.svc:3000`. It holds a `VERSION` file that says `6.15.0` and a script `test.sh` that checks it. The repository is public |
| `starfleet` | `shuttle` (a client pod with `curl`), the ServiceAccount `workflow-runner` with the Role the executor needs, and the `WorkflowTemplate` `run-tests` |

Deliberately absent: there is no `Workflow` yet, no `EventSource`, no `Sensor`, and `run-tests` has a mistake in it. The Gitea repository already has a push webhook that points at the address where the `EventSource` will listen. One port on your machine reaches into the cluster: `http://127.0.0.1:3000` is the Git server. `kubectl` already points at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
