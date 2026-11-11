# Reading A Failed TaskRun

A pipeline that only reports success teaches little. In the exam and at work, you will more often get a pipeline that fails and a question about why. This part adds the `run-tests` Task, which the playground installed with a mistake in it, to the Pipeline. You then follow the failure from the PipelineRun down to one line in a container log, and fix the Task.

## Add the test Task to the Pipeline

The Task `run-tests` already exists in `starfleet`. It expects the source in a workspace called `source`, runs `test.sh`, and reports the tested version as a result. The test must run after the clone and before the report.

<!-- astrona:playground:renew -->

Change `pipeline-scout-ci.yaml` so that the `tasks` list has three entries. The new `run-tests` entry runs after `fetch-source`, and `report-version` now runs after `run-tests`:

```yaml
  tasks:
    - name: fetch-source
      taskRef:
        name: fetch-source
      params:
        - name: url
          value: $(params.repo-url)
      workspaces:
        - name: source
          workspace: shared
    - name: run-tests
      runAfter:
        - fetch-source
      taskRef:
        name: run-tests
      workspaces:
        - name: source
          workspace: shared
    - name: report-version
      runAfter:
        - run-tests
      taskRef:
        name: report-version
      params:
        - name: version
          value: $(tasks.fetch-source.results.version)
```

Apply it, and start a new run with the same PipelineRun file:

```sh
kubectl apply -f pipeline-scout-ci.yaml
kubectl create -f pipelinerun-scout-ci.yaml
```

## From the PipelineRun to the step

Start at the top. Wait about 30 seconds, then describe the newest PipelineRun:

```sh
tkn -n starfleet pipelinerun describe --last
```

The output is (shortened to the sections that matter):

```text
Name:              scout-ci-2mk48
...
Status

STARTED          DURATION   STATUS
30 seconds ago   16s        Failed

Message

Tasks Completed: 2 (Failed: 1, Cancelled 0), Skipped: 1
TaskRun(s) cancelled: scout-ci-2mk48-run-tests
...
Taskruns

 NAME                          TASK NAME      STARTED          DURATION   STATUS
 scout-ci-2mk48-run-tests      run-tests      20 seconds ago   6s         Failed(StepFailed)
 scout-ci-2mk48-fetch-source   fetch-source   30 seconds ago   10s        Succeeded

Skipped Tasks

 NAME
 report-version
```

The PipelineRun failed. `fetch-source` succeeded, `run-tests` failed with the reason `StepFailed`, and `report-version` was skipped, because a Task that depends on a failed Task never starts. The message also lists `run-tests` under `TaskRun(s) cancelled`; when a Task fails, the controller tries to cancel the TaskRuns that are still running, and the list includes the failed one. The `Failed(StepFailed)` status of the TaskRun is the one to trust.

Go one level down, to the TaskRun, and read its logs:

```sh
tkn -n starfleet taskrun describe scout-ci-2mk48-run-tests
tkn -n starfleet taskrun logs scout-ci-2mk48-run-tests
```

The output is (the `describe` part is shortened):

```text
Status

STARTED          DURATION    STATUS
26 seconds ago   6s          Failed(StepFailed)

Message

"step-test" exited with code 2: Error

Workspaces

 NAME     SUB PATH   WORKSPACE BINDING
 source   ---        PersistentVolumeClaim (claimName=pvc-5a529a2ab1)

Steps

 NAME   STATUS
 test   Error
task run-tests has failed: "step-test" exited with code 2: Error
[test] sh: can't open 'test.sh': No such file or directory
```

Now you know which step failed, its exit code, and the error. The workspace was bound to the PVC of the run, so the clone was there. The step simply did not find `test.sh` in the folder it ran in.

## The same facts with kubectl

The exam gives you `kubectl` for sure; `tkn` may not be there. Every fact above is in the objects, so you can read it without `tkn`. The TaskRun's `Succeeded` condition holds the message, `status.steps` holds the exit code of each step, and the pod holds the log of each step container:

```sh
kubectl -n starfleet get taskrun scout-ci-2mk48-run-tests \
  -o jsonpath='{.status.conditions[0].message}{"\n"}{.status.steps[0].terminated.exitCode}{"\n"}'
kubectl -n starfleet get pod scout-ci-2mk48-run-tests-pod
kubectl -n starfleet logs scout-ci-2mk48-run-tests-pod -c step-test
```

The output is:

```text
"step-test" exited with code 2: Error
2
NAME                           READY   STATUS   RESTARTS   AGE
scout-ci-2mk48-run-tests-pod   0/1     Error    0          26s
sh: can't open 'test.sh': No such file or directory
```

The pod status is `Error`, and the container log holds the same line as `tkn`. Next, compare the folder the step ran in with the place where the workspace is mounted:

```sh
kubectl -n starfleet get task run-tests -o jsonpath='{.spec.steps[0].workingDir}{"\n"}'
kubectl -n starfleet get pod scout-ci-2mk48-run-tests-pod \
  -o jsonpath='{range .spec.containers[0].volumeMounts[*]}{.mountPath}{"\n"}{end}'
```

The output is:

```text
/workspace/wrong
/workspace/source
/tekton/scripts
/tekton/downward
/tekton/creds
/tekton/run/0
/tekton/bin
/workspace
/tekton/home
/tekton/results
/tekton/steps
/tekton/artifacts
/var/run/secrets/kubernetes.io/serviceaccount
```

The step runs in `/workspace/wrong`, but the workspace `source` is mounted at `/workspace/source`. An extra init container in this pod, `working-dir-initializer`, creates a missing `workingDir` under `/workspace` before the step starts, so the step did not fail on the folder itself. It failed on the first file it looked for. The other mounts under `/tekton` are Tekton's own: the scripts, the results, the entrypoint program and the step status files.

## Fix the Task

The fix is to point `workingDir` at the workspace with the variable, not with a fixed path.

Save this as `task-run-tests.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: run-tests
  namespace: starfleet
spec:
  params:
    - name: version
      type: string
      default: 6.15.0
  workspaces:
    - name: source
  results:
    - name: version
      description: The tested application version
  steps:
    - name: test
      image: alpine:3.23
      workingDir: $(workspaces.source.path)
      env:
        - name: SCOUT_VERSION
          value: $(params.version)
      script: |
        #!/bin/sh
        set -eu
        sh test.sh
        printf '%s' "$SCOUT_VERSION" > "$(results.version.path)"
```

Apply it, and start a new run:

```sh
kubectl apply -f task-run-tests.yaml
kubectl create -f pipelinerun-scout-ci.yaml
```

Then check the result after about 30 seconds:

```sh
tkn -n starfleet pipelinerun logs --last
tkn -n starfleet pipelinerun list
```

The output is:

```text
[fetch-source : clone] Cloned commit 9962c15

[run-tests : test] Checking VERSION
[run-tests : test] Tests passed for scout 6.15.0

[report-version : show-system] Running on 3.23.6

[report-version : write-summary] Reporting version 6.15.0

NAME             STARTED          DURATION   STATUS
scout-ci-vc5rl   35 seconds ago   20s        Succeeded
scout-ci-2mk48   1 minute ago     16s        Failed
scout-ci-7qjcd   1 minute ago     16s        Succeeded
```

The test ran in the workspace and passed, and all three Tasks ran in order. The failed run is still in the list: Tekton never changes an old run, so the record of the failure stays until you delete it.

## A run that fails before any pod starts

Not every failure has a pod to read. When the PipelineRun itself is wrong, the controller rejects it before it creates any TaskRun. Save this as `pipelinerun-no-workspace.yaml`, a run that forgets the workspace:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: scout-ci-
  namespace: starfleet
spec:
  pipelineRef:
    name: scout-ci
```

Create it, and describe it:

```sh
kubectl create -f pipelinerun-no-workspace.yaml
tkn -n starfleet pipelinerun describe --last
```

The output is (shortened):

```text
pipelinerun.tekton.dev/scout-ci-dglvj created
...
STARTED         DURATION   STATUS
4 seconds ago   0s         Failed(InvalidWorkspaceBindings)

Message

[User error] PipelineRun starfleet/scout-ci-dglvj doesn't bind Pipeline starfleet/scout-ci's Workspaces correctly: pipeline requires workspace with name "shared" be provided by pipelinerun
```

The API server accepted the object, so `kubectl create` reported success. The Tekton controller then failed the run with the reason `InvalidWorkspaceBindings` and a message that names the missing workspace. No TaskRun and no pod exist for this run, so the message on the PipelineRun is the only place to look.

You can now read a failure at each level: the PipelineRun's message and Task list, the TaskRun's step status and exit code, and the step container's log, with `tkn` or with `kubectl` alone. You also saw that a broken run definition fails on the PipelineRun without any pod. Every Task so far lives in `starfleet`, though, and the open question is how many teams can use one Task without each keeping a copy.

## Common pitfalls

> [!WARNING]
> - **Stopping at the PipelineRun.** Its message only counts Tasks. The cause is on the failed TaskRun and in its step log.
> - **Taking "cancelled" literally.** A failed TaskRun can appear in the `TaskRun(s) cancelled` list of the PipelineRun message. Read the TaskRun's own status.
> - **Looking for a pod when the reason is a validation error.** Reasons such as `InvalidWorkspaceBindings` or `TaskRunValidationFailed` mean no pod was created.
> - **Hard-coding `/workspace/<name>`.** Use `$(workspaces.<name>.path)`, so the step still works if the path changes.
> - **Fixing an old run.** A finished run never changes. Fix the Task or the Pipeline and start a new run.
