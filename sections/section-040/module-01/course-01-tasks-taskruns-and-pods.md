# Tasks, TaskRuns And Pods

A CI system must run the same commands the same way for every change, and it must keep a record of what ran and what came out. Tekton does both with Kubernetes objects. This part writes the smallest useful Task, runs it twice, and then looks underneath at the pod and the containers that did the work.

## Four objects, two kinds of definition

Tekton separates what to run from one run of it. A **Task** is a list of steps that run as containers in one pod. A **TaskRun** is one run of a Task, with the values for its parameters and, after it ends, its status and results. A **Pipeline** is an ordered graph of Tasks, and a **PipelineRun** is one run of a Pipeline.

The Task and the Pipeline are definitions: you write them once and they do nothing on their own. The TaskRun and the PipelineRun are the runs: each one starts work, and each one stays in the cluster afterwards as a record. The Tekton controller in the namespace `tekton-pipelines` watches the runs and creates the pods for them.

## A Task with a parameter and a result

The first Task reports a version of `scout`. It takes the version as a **param**, a named input value the run supplies. It writes one line as a **result**, a small named output value that Tekton stores in the run's status.

<!-- astrona:playground:renew -->

Save this as `task-report-version.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: report-version
  namespace: starfleet
spec:
  params:
    - name: version
      type: string
      description: The version to report
      default: 6.15.0
  results:
    - name: summary
      description: One line that names the version
  steps:
    - name: show-system
      image: alpine:3.23
      script: |
        #!/bin/sh
        echo "Running on $(cat /etc/alpine-release)"
    - name: write-summary
      image: alpine:3.23
      script: |
        #!/bin/sh
        echo "Reporting version $(params.version)"
        printf 'scout %s' "$(params.version)" > "$(results.summary.path)"
```

The fields that matter are these:

- `params` declares the inputs. A param with a `default` is optional; one without a default must be set by every run.
- `results` declares the outputs. A step writes a result by writing to the file `$(results.<name>.path)`.
- `steps` is the list of containers. Each step has a `name`, an `image`, and either a `script` or a `command` with `args`. Steps run in the order of the list.
- `$(params.version)` is a Tekton variable. The controller replaces it with the value before the pod starts, so the script sees plain text.

Apply it:

```sh
kubectl apply -f task-report-version.yaml
```

Nothing runs yet. The Task is only stored in the cluster.

## Run it with a TaskRun

A TaskRun names the Task in `taskRef` and sets the params. Each run needs a new name, so this file uses `generateName`: the API server adds a random suffix to `report-version-`.

Save this as `taskrun-report-version.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: report-version-
  namespace: starfleet
spec:
  taskRef:
    name: report-version
  params:
    - name: version
      value: 6.14.0
```

An object with `generateName` cannot be applied with `kubectl apply`, because apply needs a fixed name. Create it instead:

```sh
kubectl create -f taskrun-report-version.yaml
```

The output names the new run:

```text
taskrun.tekton.dev/report-version-9xdp6 created
```

Your suffix differs. Wait a few seconds, then check the result with `kubectl` and read the logs with `tkn`:

```sh
kubectl -n starfleet get taskruns
tkn -n starfleet taskrun logs --last
```

You should see:

```text
NAME                   SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
report-version-9xdp6   True        Succeeded   12s         4s
[show-system] Running on 3.23.6

[write-summary] Reporting version 6.14.0
```

`SUCCEEDED` is the `Succeeded` condition of the TaskRun, set by the Tekton controller. `tkn taskrun logs` prints the log of every step, and puts the step name in brackets in front of each line. The param value `6.14.0` from the TaskRun replaced the default.

`tkn` can also create the TaskRun for you. `tkn task start` builds the run from the Task, `-p` sets a param, and `--showlog` follows the logs until the run ends:

```sh
tkn -n starfleet task start report-version -p version=6.15.0 --showlog
```

The output is:

```text
TaskRun started: report-version-run-sqm8t
Waiting for logs to be available...
[show-system] Running on 3.23.6

[write-summary] Reporting version 6.15.0
```

Both ways create the same kind of object. A file is better when the run must be repeated or reviewed; `tkn task start` is faster when you try something by hand.

## The pod underneath

A TaskRun is only a record. The work happens in a pod that the Tekton controller creates for it. Read the full status of the first run, then list the containers of its pod:

```sh
tkn -n starfleet taskrun describe report-version-9xdp6
kubectl -n starfleet get pod report-version-9xdp6-pod \
  -o jsonpath='{range .spec.initContainers[*]}init: {.name}{"\n"}{end}{range .spec.containers[*]}container: {.name}{"\n"}{end}'
```

The output is (the `describe` part is shortened to the sections that matter):

```text
Name:              report-version-9xdp6
Namespace:         starfleet
Task Ref:          report-version
Service Account:   default
...
Params

 NAME      VALUE
 version   6.14.0

Results

 NAME      VALUE
 summary   scout 6.14.0

Steps

 NAME            STATUS
 show-system     Completed
 write-summary   Completed
init: prepare
init: place-scripts
container: step-show-system
container: step-write-summary
```

The result `summary` holds `scout 6.14.0`, the line the second step wrote. The pod is named after the TaskRun with `-pod` at the end. Each step became a container named `step-<step name>`. Two init containers ran first: `prepare` copies Tekton's entrypoint program into the pod, and `place-scripts` writes each `script` to a file.

The containers of a pod normally start together. Tekton makes them run one after the other: its entrypoint program wraps the command of each step container and waits until the step before it has finished. The service account is `default`, because the TaskRun named none.

You can now write a Task, run it with a file or with `tkn`, and read its status, results and logs. Each step ran in its own container, so the second step could not see a file the first step wrote anywhere except in the result. The open question is how steps and Tasks share real files, such as a cloned Git repository.

## Common pitfalls

> [!WARNING]
> - **Running `kubectl apply` on a TaskRun with `generateName`.** Apply needs a fixed `metadata.name`. Use `kubectl create`, or give each run its own name.
> - **Expecting a Task to run when you apply it.** A Task is a definition. Only a TaskRun or a PipelineRun starts a pod.
> - **Leaving out a param that has no default.** The run fails before any pod starts. Give the param a `default`, or set it in every run.
> - **Writing a result with `echo`.** `echo` adds a newline that ends up in the value. Use `printf` to write `$(results.<name>.path)`.
> - **Looking for the step by its own name in `kubectl logs`.** The container is called `step-<step name>`, for example `step-write-summary`.
