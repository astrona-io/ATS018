# Solution

## Step 1: run the template and read the failure

Save this as `workflow-run-tests.yaml`:

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

Create it, wait about 30 seconds and list the Workflows:

```sh
kubectl create -f workflow-run-tests.yaml
kubectl -n starfleet get workflows
```

The Workflow is `Failed` with the message `main: Error (exit code 2)`. Read the log of its pod. Replace `<workflow-name>` with the name from the list:

```sh
kubectl -n starfleet logs -l workflows.argoproj.io/workflow=<workflow-name> -c main --prefix | grep -v INFO
```

The log says `/bin/sh: can't open 'test.sh': No such file or directory`. Read the folder the container starts in:

```sh
kubectl -n starfleet get workflowtemplate run-tests -o jsonpath='{.spec.templates[0].container.workingDir}{"\n"}'
```

The container starts in `/wrong`. The template clones the repository to `/src` (the `path` of the git artifact), so `test.sh` is in `/src`.

## Step 2: fix the template

Save this as `workflowtemplate-run-tests.yaml`:

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

Apply it:

```sh
kubectl apply -f workflowtemplate-run-tests.yaml
```

## Step 3: receive the push

An EventSource of the type `webhook` starts an HTTP server and a Service in front of it. The Service name is the EventSource name plus `-eventsource-svc`, which is the address Gitea calls. Save this as `eventsource-push-webhook.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: push-webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    push:
      port: "12000"
      endpoint: /push
      method: POST
```

Apply it:

```sh
kubectl apply -f eventsource-push-webhook.yaml
```

## Step 4: filter the event and start the Workflow

The EventSource wraps the HTTP body of the push in a field `body`, so the Sensor filters `body.ref`. The trigger copies `body.after`, the ID of the pushed commit, into the first argument of the Workflow. Save this as `sensor-push-ci.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: push-ci
  namespace: argo-events
spec:
  template:
    serviceAccountName: workflow-submitter
  dependencies:
    - name: push-main
      eventSourceName: push-webhook
      eventName: push
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - refs/heads/main
  triggers:
    - template:
        name: run-tests
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: push-ci-
                namespace: starfleet
              spec:
                workflowTemplateRef:
                  name: run-tests
                arguments:
                  parameters:
                    - name: revision
                      value: main
          parameters:
            - src:
                dependencyName: push-main
                dataKey: body.after
              dest: spec.arguments.parameters.0.value
```

Apply it:

```sh
kubectl apply -f sensor-push-ci.yaml
```

Then check that the Service and the pods exist:

```sh
kubectl -n argo-events get svc,pods
```

The Service `push-webhook-eventsource-svc` exists, and the pods of the EventSource and the Sensor are `Running`. Wait until both are `Running` before you push.

## Step 5: push a commit and read the run

Clone the repository, change `VERSION` and push to `main`:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-app.git
cd scout-app
echo 6.15.1 > VERSION
git commit -am "Bump VERSION to 6.15.1"
git push origin main
git rev-parse HEAD
```

After about 30 seconds, list the Workflows and read the revision of the newest one that starts with `push-ci-`:

```sh
kubectl -n starfleet get workflows
kubectl -n starfleet get workflows -l events.argoproj.io/sensor=push-ci \
  -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.status.phase}{"  "}{.spec.arguments.parameters[0].value}{"\n"}{end}'
```

The Workflow created by the Sensor is `Succeeded`, and its revision is the commit ID that `git rev-parse HEAD` printed.

If no Workflow appears, read the Sensor log with `kubectl -n argo-events logs -l sensor-name=push-ci`. If you pushed before the pods were `Running`, push a new commit.

## Step 6: submit

```sh
astrona submit
```

The first check reads the WorkflowTemplate. The second check reads the EventSource, the Sensor, their pods and the filter. The third check compares the newest commit on `main` with the revision of a `Succeeded` Workflow that carries the label of the Sensor `push-ci`.
