# Read A Failed Workflow

CI runs fail, and in an exam task the failure is the task. You get a Workflow that does not pass, and you must find the cause and fix it. The status of a Workflow tells you which node failed, and the logs of that node's pod tell you why. This part breaks three runs in three different ways and reads each one with `kubectl`.

## The path from a failed Workflow to its cause

Three places hold the answer, and you read them in the same order every time. First, the phase and the message of the Workflow, from `kubectl get workflows`. Second, the nodes in `status.nodes`: each node has a `phase` and a `message`, and the failed node is the one with the phase `Failed` or `Error`. Third, the logs of the pod of that node, from `kubectl logs`.

The two failure phases mean different things. `Failed` means a pod ran and one of its containers ended with a non-zero exit code. `Error` means the run could not work as it should, for example a template that is missing or a pod that cannot report its result. A node that never started because a task it depends on failed has the phase `Omitted`.

<!-- astrona:playground:renew -->

Start with a task that fails in a DAG. The Workflow below uses the `scout-ci` WorkflowTemplate (a DAG of the tasks `clone`, `read-version`, `test` and `report`, which must exist in `starfleet`), but asks for a branch, `nope`, that does not exist in the repository. Save this as `workflow-scout-ci-bad-revision.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: scout-ci-nope-
  namespace: starfleet
spec:
  workflowTemplateRef:
    name: scout-ci
  arguments:
    parameters:
      - name: revision
        value: nope
```

Create it and list the nodes with their phases and messages:

```sh
kubectl create -f workflow-scout-ci-bad-revision.yaml
kubectl -n starfleet get workflows
NAME=$(kubectl -n starfleet get workflows -o name | grep nope)
kubectl -n starfleet get $NAME -o jsonpath='{range .status.nodes.*}{.displayName}{"\t"}{.phase}{"\t"}{.message}{"\n"}{end}'
```

The output is (your suffix is different, and the playground may list other Workflows too):

```text
workflow.argoproj.io/scout-ci-nope-pvrkg created
NAME                  STATUS   AGE   MESSAGE
scout-ci-nope-pvrkg   Failed   40s   
report	Omitted	omitted: depends condition not met
read-version	Omitted	omitted: depends condition not met
clone	Failed	main: Error (exit code 128)
test	Omitted	omitted: depends condition not met
scout-ci-nope-pvrkg	Failed	
```

Only `clone` has the phase `Failed`. The three tasks that depend on it are `Omitted`, so they are a result of the failure and not a second failure. The message `main: Error (exit code 128)` says that the container `main` of the `clone` pod exited with code 128. Read its log for the reason:

```sh
kubectl -n starfleet logs -l workflows.argoproj.io/workflow=${NAME#*/} -c main --prefix | grep -v INFO
```

The output is:

```text
[pod/scout-ci-nope-pvrkg-clone-2965054559/main] Cloning into '/work/src'...
[pod/scout-ci-nope-pvrkg-clone-2965054559/main] fatal: Remote branch nope not found in upstream origin
[pod/scout-ci-nope-pvrkg-clone-2965054559/main] Error: exit status 128
```

`git` says that the remote has no branch `nope`. The cause is the argument, not the template, so the fix is a new run with `revision: main`.

## A test that fails in its own container

The template `run-tests` is the second case. It runs `test.sh` against the repository, and it gets the repository as a git input artifact: the `init` container clones it into `/src` before `main` starts. Start a run from it. Save this as `workflow-run-tests.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: run-tests-
  namespace: starfleet
spec:
  workflowTemplateRef:
    name: run-tests
```

```sh
kubectl create -f workflow-run-tests.yaml
kubectl -n starfleet get workflows
```

The output is (shortened to the new Workflow):

```text
workflow.argoproj.io/run-tests-q9q7b created
NAME              STATUS   AGE   MESSAGE
run-tests-q9q7b   Failed   25s   main: Error (exit code 2)
```

A Workflow with one container template has one pod, and the pod has the name of the Workflow. Read the log of its `main` container:

```sh
kubectl -n starfleet logs run-tests-q9q7b -c main | grep -v INFO
```

The output is:

```text
/bin/sh: can't open 'test.sh': No such file or directory
Error: exit status 2
```

The shell cannot find `test.sh`, although the artifact holds it. The template sets the working directory of the container to `/wrong`, but the repository is at `/src`. Save the corrected template as `workflowtemplate-run-tests.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: run-tests
  namespace: starfleet
spec:
  entrypoint: test
  serviceAccountName: workflow-runner
  arguments:
    parameters:
      - name: revision
        value: main
  templates:
    - name: test
      inputs:
        parameters:
          - name: revision
        artifacts:
          - name: source
            path: /src
            git:
              repo: http://gitea-http.gitea.svc:3000/starfleet/scout-app.git
              revision: "{{inputs.parameters.revision}}"
      container:
        image: alpine:3.23
        workingDir: /src
        command: [sh, test.sh]
```

Apply it, start a new run and read its log. The old Workflow keeps its failed result, because a run uses the template as it was when the run started:

```sh
kubectl apply -f workflowtemplate-run-tests.yaml
kubectl create -f workflow-run-tests.yaml
NAME=$(kubectl -n starfleet get workflows --sort-by=.metadata.creationTimestamp -o name | tail -1)
kubectl -n starfleet logs ${NAME#*/} -c main | grep -v INFO
```

The output is :

```text
workflowtemplate.argoproj.io/run-tests configured
workflow.argoproj.io/run-tests-r2f9n created
Checking VERSION
Tests passed for scout 6.15.0
```

## An Error from the executor

The third case has a different phase. The Workflow below has no `serviceAccountName`, so its pod runs as the `default` ServiceAccount. Save it as `workflow-default-account.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-
  namespace: starfleet
spec:
  entrypoint: main
  templates:
    - name: main
      container:
        image: alpine:3.23
        command: [echo, hello]
```

```sh
kubectl create -f workflow-default-account.yaml
kubectl -n starfleet get workflows
```

The output is (shortened to the new Workflow):

```text
workflow.argoproj.io/hello-gckgb created
NAME          STATUS   AGE   MESSAGE
hello-gckgb   Error    40s   wait: Error (exit code 64): workflowtaskresults.argoproj.io is forbidden: User "system:serviceaccount:starfleet:default" cannot create resource "workflowtaskresults" in API group "argoproj.io" in the namespace "starfleet"
```

The message names the container that failed (`wait`, the executor), the missing permission (create `workflowtaskresults`) and the account that lacks it (`default` in `starfleet`). The command in `main` ran fine and printed `hello`. The executor could not report the result to the controller. The fix is the one the earlier Workflows used: set `spec.serviceAccountName: workflow-runner`, an account that has a Role with that permission.

You can now follow a failure from the phase to the node to the log, and you can tell `Failed`, `Omitted` and `Error` apart. The remaining piece of a CI system is the trigger: nobody wants to run `kubectl create` after every push.

## Common pitfalls

> [!WARNING]
> - `kubectl logs` on a Workflow name only works when the Workflow has a single pod. For a DAG, select the pods with the label `workflows.argoproj.io/workflow=<name>`.
> - The `main` log contains executor lines with `level=INFO`. The `wait` container holds the executor's own log. For an `Error` phase, read the `wait` container too.
> - Fixing a `WorkflowTemplate` does not repair a Workflow that already failed. Start a new run.
> - Do not look for the cause in the `Omitted` nodes. Find the node with the phase `Failed` or `Error`.
