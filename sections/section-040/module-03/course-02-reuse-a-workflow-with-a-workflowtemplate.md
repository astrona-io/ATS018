# Reuse A Workflow With A WorkflowTemplate

A graph of tasks that you paste into every run is hard to keep correct. When the test step changes, you must find every copy. Argo Workflows solves this the same way a function does: you define the graph once in a `WorkflowTemplate`, and each run only names the template and gives arguments. This part puts a four-task graph into a template and starts a run from it.

## A template, a reference and arguments

A `WorkflowTemplate` is a namespaced object with the same `spec` as a Workflow: an `entrypoint`, `templates`, default `arguments` and a `serviceAccountName`. It never runs by itself. A Workflow starts a run from it with `spec.workflowTemplateRef.name`. The Workflow controller then reads the template, merges the `arguments` of the Workflow over the default arguments of the template, and runs the result.

The reference makes a Workflow very small. All it holds is the name of the template and the values that change per run. Fields that you leave out, such as `serviceAccountName` and `entrypoint`, come from the template.

<!-- astrona:playground:renew -->

First start a run that refers to a template that does not exist yet. Save this as `workflow-scout-ci-from-template.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: scout-ci-release-
  namespace: starfleet
spec:
  workflowTemplateRef:
    name: scout-ci
  arguments:
    parameters:
      - name: revision
        value: main
```

Create it and read the phase and the message:

```sh
kubectl create -f workflow-scout-ci-from-template.yaml
kubectl -n starfleet get workflows
```

The output is:

```text
workflow.argoproj.io/scout-ci-release-sdv6z created
NAME                     STATUS   AGE   MESSAGE
scout-ci-release-sdv6z   Error    5s    workflowtemplates.argoproj.io "scout-ci" not found
```

The phase `Error` means that the controller could not even start the run, and the message says why. No pod exists. Compare this with `Failed`, which means that a node ran and ended with a failure. The next step creates the template.

## Create the WorkflowTemplate

The template below holds a DAG of four tasks: `clone`, then `read-version` and `test` in parallel, then `report`. It has a fixed name, `scout-ci`, because other objects refer to it.

Save this as `workflowtemplate-scout-ci.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: scout-ci
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

Apply it:

```sh
kubectl apply -f workflowtemplate-scout-ci.yaml
```

Then check the result, and start the run again. The old Workflow stays in the `Error` phase, so delete it first:

```sh
kubectl -n starfleet get workflowtemplates
kubectl -n starfleet delete workflows --all >/dev/null
kubectl create -f workflow-scout-ci-from-template.yaml
kubectl -n starfleet wait --for=jsonpath='{.status.phase}'=Succeeded workflow --all --timeout=150s
kubectl -n starfleet get workflows
```

The output is (your suffixes are different):

```text
NAME        AGE
run-tests   32m
scout-ci    0s
workflow.argoproj.io/scout-ci-release-pq24c created
workflow.argoproj.io/scout-ci-release-pq24c condition met
NAME                     STATUS      AGE   MESSAGE
scout-ci-release-pq24c   Succeeded   40s   
```

The list shows two templates. `run-tests` came with the playground, and `scout-ci` is yours. The run succeeded with a short Workflow, and the ServiceAccount `workflow-runner` came from the template. To run another revision of the repository, change the value of `revision` in the Workflow. The template stays the same.

You can now define a graph once and start runs from it. The `run-tests` template in the playground is a second example: it has one task, and it fetches the repository with a git input artifact instead of a clone task. Its run does not pass yet, and finding out why is the next skill to learn.

## Common pitfalls

> [!WARNING]
> - A Workflow can only refer to a `WorkflowTemplate` in its own namespace. Create the template in `starfleet`, where the Workflow runs.
> - The phase `Error` is not the phase `Failed`. `Error` means the controller could not run the Workflow (a missing template or a bad reference), and the `MESSAGE` column shows the reason.
> - The Workflow in this part gets its `serviceAccountName` and `entrypoint` from the template. If you also set them in the Workflow, the value in the Workflow is the one that counts.
