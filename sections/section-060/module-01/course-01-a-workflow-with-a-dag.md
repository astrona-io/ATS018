# A Workflow With A DAG

A CI run is more than one command. It clones the code, runs tests, reads a version and reports a result, and some of these steps can run at the same time. Argo Workflows describes such a run as one Kubernetes object, a `Workflow`. This part writes a Workflow with four tasks, passes data between them, and looks at the pods that the controller creates.

## What the controller does with a Workflow

A `Workflow` is a custom resource. Its `spec` holds a list of `templates`, and one template is the `entrypoint`, the template where the run starts. The Workflow controller (the `workflow-controller` Deployment in `starfleet`) watches Workflow objects. For every template that runs a container, the controller creates a pod, waits for it to finish and writes the result into the `status` of the Workflow.

A template can be a container template, which runs one container, or a DAG template. A DAG (directed acyclic graph) template does not run anything itself. It lists tasks, and each task points at another template. A task can say `depends` on other tasks, and the controller starts a task as soon as its dependencies are done. Tasks without a dependency between them run at the same time.

Every pod of a Workflow has three containers or more. The `main` container runs your image. The `wait` container is the Argo executor: it waits for `main` to finish, collects the outputs and reports them to the controller. Git input artifacts add an `init` container. The ServiceAccount of the pod needs one permission for this reporting: it must be allowed to create `workflowtaskresults`. The playground already has a ServiceAccount named `workflow-runner` with that permission.

## Write the Workflow

The Workflow below runs four tasks. `clone` fetches the `scout-app` repository into a volume. `read-version` and `test` both depend on `clone`, so they run in parallel. `report` depends on both and prints the version that `read-version` found.

The Workflow also shows three ways to move data. The argument `revision` is a Workflow parameter, and `{{workflow.parameters.revision}}` reads it. The output parameter `version` of `read-version` is read from the file `/tmp/version` and passed to `report` as `{{tasks.read-version.outputs.parameters.version}}`. The files from `clone` reach the other tasks through a volume that `volumeClaimTemplates` creates for this one run.

<!-- astrona:playground:renew -->

Save this as `workflow-scout-ci.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: scout-ci-
  namespace: starfleet
spec:
  entrypoint: ci
  serviceAccountName: workflow-runner
  arguments:
    parameters:
      - name: revision
        value: main
  volumeClaimTemplates:
    - metadata:
        name: work
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Mi
  templates:
    - name: ci
      dag:
        tasks:
          - name: clone
            template: clone
          - name: read-version
            template: read-version
            depends: clone
          - name: test
            template: test
            depends: clone
          - name: report
            template: report
            depends: read-version && test
            arguments:
              parameters:
                - name: version
                  value: "{{tasks.read-version.outputs.parameters.version}}"
    - name: clone
      container:
        image: alpine/git:2.52.0
        args: ["clone", "--branch", "{{workflow.parameters.revision}}", "http://gitea-http.gitea.svc:3000/starfleet/scout-app.git", "/work/src"]
        volumeMounts:
          - name: work
            mountPath: /work
    - name: read-version
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["cp /work/src/VERSION /tmp/version"]
        volumeMounts:
          - name: work
            mountPath: /work
      outputs:
        parameters:
          - name: version
            valueFrom:
              path: /tmp/version
    - name: test
      container:
        image: alpine:3.23
        workingDir: /work/src
        command: [sh, test.sh]
        volumeMounts:
          - name: work
            mountPath: /work
    - name: report
      inputs:
        parameters:
          - name: version
      container:
        image: alpine:3.23
        command: [echo]
        args: ["scout {{inputs.parameters.version}} passed all checks"]
```

The Workflow has no fixed name. `generateName: scout-ci-` makes the API server add a random suffix, so you can run it many times. An object with `generateName` cannot be applied, so create it:

```sh
kubectl create -f workflow-scout-ci.yaml
kubectl -n starfleet get workflows
```

The output is (your suffix is different):

```text
workflow.argoproj.io/scout-ci-9rhpq created
NAME             STATUS    AGE   MESSAGE
scout-ci-9rhpq   Running   2s    
```

The controller already reads the object and runs it. The `STATUS` column is the phase of the Workflow: `Pending`, `Running`, `Succeeded`, `Failed` or `Error`.

## Read the nodes and the pods

Wait until the Workflow is done. Then list its nodes. A node is one step of the run: the DAG itself and each task. The `status.nodes` field of the Workflow holds them, and `status.progress` counts the finished pods.

```sh
kubectl -n starfleet wait --for=jsonpath='{.status.phase}'=Succeeded workflow --all --timeout=150s
NAME=$(kubectl -n starfleet get workflows -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet get workflow $NAME -o jsonpath='{range .status.nodes.*}{.displayName}{"\t"}{.type}{"\t"}{.phase}{"\n"}{end}'
kubectl -n starfleet get workflow $NAME -o jsonpath='{.status.phase}{" "}{.status.progress}{"\n"}'
kubectl -n starfleet get pods
```

The output is (shortened: the order of the nodes can differ, and your pod names have other numbers):

```text
workflow.argoproj.io/scout-ci-9rhpq condition met
report	Pod	Succeeded
read-version	Pod	Succeeded
scout-ci-9rhpq	DAG	Succeeded
test	Pod	Succeeded
clone	Pod	Succeeded
Succeeded 4/4
NAME                                     READY   STATUS      RESTARTS   AGE
scout-ci-9rhpq-clone-2386455724          0/2     Completed   0          30s
scout-ci-9rhpq-read-version-3441803751   0/2     Completed   0          20s
scout-ci-9rhpq-report-4076052689         0/2     Completed   0          10s
scout-ci-9rhpq-test-3259882523           0/2     Completed   0          20s
```

The DAG node has the name of the Workflow, and each task is a node of type `Pod`. Each pod name is the Workflow name, the task name and a number. The pods show `0/2` ready because both containers, `main` and `wait`, have ended. The ages show the order: `clone` started first, `read-version` and `test` started together ten seconds later, and `report` started last.

The pods keep their logs after they finish. The `main` container holds the output of your command, and the `wait` container holds the executor log lines. Filter the executor lines out to read only your own output:

```sh
kubectl -n starfleet logs -l workflows.argoproj.io/workflow=$NAME -c main --prefix | grep -v 'level=INFO'
```

The output is:

```text
[pod/scout-ci-9rhpq-report-4076052689/main] scout 6.15.0 passed all checks
[pod/scout-ci-9rhpq-test-3259882523/main] Checking VERSION
[pod/scout-ci-9rhpq-test-3259882523/main] Tests passed for scout 6.15.0
[pod/scout-ci-9rhpq-clone-2386455724/main] Cloning into '/work/src'...
```

The label `workflows.argoproj.io/workflow` is on every pod of a Workflow, so one `kubectl logs -l` reads the whole run. The `report` line shows that the output parameter reached its task: `6.15.0` was read by `read-version` from the file and passed on as an argument.

The shared volume was created for this run only. The controller deletes the PersistentVolumeClaim when the Workflow ends, so `kubectl -n starfleet get pvc` returns `No resources found in starfleet namespace.` The Workflow object itself stays until you delete it.

You now know how a Workflow turns into pods: one pod per task, ordered by `depends`, with parameters and a volume for the data. One question is open. The Workflow spec is long, and every run needs a copy of it. The next step is to define the graph once and start many runs from it.

## Common pitfalls

> [!WARNING]
> - `kubectl apply` fails on a Workflow with `generateName`, because apply needs a fixed name. Use `kubectl create -f`, or give the Workflow a `name`.
> - A Workflow that uses the `default` ServiceAccount ends in `Error`, because `default` cannot create `workflowtaskresults`. Set `spec.serviceAccountName`.
> - `kubectl get pods` shows `0/2` for a finished task pod. That is normal. Look at the phase of the node, not at the ready count.
> - A task that is listed in `depends` but fails makes all tasks that depend on it `Omitted`. They do not run, and they do not show an error of their own.
