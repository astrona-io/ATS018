# Build Tekton Tasks And Pipelines

A GitOps controller delivers what is in Git, but something has to test the code and produce the new version first. That job is continuous integration (CI): every change runs the same checks in the same way, and the result is a version that is ready to deliver. On Kubernetes, the CI system the exam teaches is Tekton.

Tekton is a set of controllers and custom resources that run CI work inside the cluster. A Tekton Task is a list of steps, and each step is a container. When you run a Task, the Tekton controller creates one pod for it, and the steps run one after the other as containers in that pod. A Tekton Pipeline puts several Tasks in order and lets them share files and values.

Keep one sentence in mind for this module: **every run is a Kubernetes object with a status, and every step is a container with a log.** When something fails, you read the status of the run, then the status of the step, then the log of that container.

The module has four parts. **Tasks, TaskRuns And Pods** writes a Task with a parameter and a result, runs it, and finds the pod and the containers it created. **Workspaces, Pipelines And Results** clones a Git repository into a shared volume and chains two Tasks in a Pipeline that passes a result from one to the next. **Reading A Failed TaskRun** adds a broken test Task to the Pipeline and follows the failure from the PipelineRun down to the container log. **Shared Tasks With Resolvers** loads Tasks from another namespace and from a Git repository instead of copying them.

## Learning objectives

After this module you can:

- Write a Task with params, steps, results and a workspace.
- Chain Tasks in a Pipeline with `runAfter` and pass a result from one Task to the next.
- Start a PipelineRun with a PersistentVolumeClaim workspace and read its logs with `tkn`.
- Reference a shared Task through the cluster or git resolver instead of copying it.
- Diagnose a failed TaskRun from its step status and the pod logs.

## Before you start

You need Kubernetes basics: namespaces, pods, containers, PersistentVolumeClaims, and the commands `kubectl get`, `kubectl apply`, `kubectl create` and `kubectl logs`. You also need the `tkn` command-line tool version 0.46 on your machine. `tkn` is the Tekton command-line tool; it reads the same objects as `kubectl` and shows them in a shorter form.

Your playground is a single-node `kind` cluster running Kubernetes 1.35 with these parts:

| Part | What it is |
| --- | --- |
| Tekton Pipelines 1.17.0 | The controller, the admission webhook and the remote resolvers, in `tekton-pipelines` and `tekton-pipelines-resolvers` |
| The Task `run-tests` in `starfleet` | A Task that runs the test script of `scout`. It fails on purpose |
| A public Git repository | `http://gitea-http.gitea.svc:3000/starfleet/scout-app.git` inside the cluster. It holds the files `VERSION` and `test.sh`, and a shared Task in `tekton/run-tests.yaml` |
| `shuttle` in `starfleet` | A client pod with `curl` |

The repository is served by Gitea, a small Git server that runs in the cluster; from your machine it answers on `http://127.0.0.1:3000`. There is no Pipeline, no Tekton Triggers and no container registry. The node already holds the step images `alpine:3.23` and `alpine/git:2.52.0`. `kubectl` already points at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
