# Start A Workflow From A Git Push

A CI system that waits for `kubectl create` is not a CI system. The run must start by itself when someone pushes code. Argo Workflows cannot listen for a push. Argo Events does that job: it receives the webhook, and it creates the Workflow. This part builds the path from a Git push to a finished run and proves it with a real push.

## The three objects of Argo Events

Argo Events splits the job into three objects that you create in the `argo-events` namespace. An `EventSource` receives events from the outside. A `webhook` event source starts an HTTP server in a pod, and creates a Service in front of it. An `EventBus` carries events inside the cluster. Here it is one NATS JetStream pod, `eventbus-default-js-0`, and the playground has already created it. A `Sensor` subscribes to events on the bus, filters them, and runs a trigger. The trigger here creates a Workflow in `starfleet`.

Gitea, the Git server of the playground, already has a webhook on `scout-app`. On every push it sends an HTTP `POST` with a JSON body to `http://push-webhook-eventsource-svc.argo-events.svc:12000/push`. That address does not answer yet, because no `EventSource` exists. The body of a push has the fields `ref` (the pushed branch, such as `refs/heads/main`) and `after` (the ID of the new commit). The Sensor uses both.

<!-- astrona:playground:renew -->

## Receive the push

The `EventSource` below is named `push-webhook`. Its `webhook` map has one event named `push`, which listens on port `12000` at the path `/push` for `POST` requests. The `service` field makes the controller create a Service for the port. The Service gets the name `push-webhook-eventsource-svc`, which is the address that Gitea already calls.

Save this as `eventsource-push-webhook.yaml`:

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

Then check the result:

```sh
kubectl -n argo-events get svc
```

The output is (your cluster IP is different):

```text
NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                               AGE
eventbus-default-js-svc        ClusterIP   None            <none>        4222/TCP,6222/TCP,7777/TCP,8222/TCP   9m38s
push-webhook-eventsource-svc   ClusterIP   10.96.128.132   <none>        12000/TCP                             46s
```

The Events controller (`controller-manager`) read the `EventSource`, started a pod for it, and created the Service `push-webhook-eventsource-svc` on port `12000`. The other Service belongs to the bus.

## Filter the event and start a Workflow

The `Sensor` has two parts. `dependencies` names the events it waits for: here the event `push` of the event source `push-webhook`, with a data filter. The filter looks at `body.ref` (the event source wraps the HTTP body in a field `body`) and lets only `refs/heads/main` pass. `triggers` says what to do. The `argoWorkflow` trigger with the operation `submit` creates the Workflow that is written in `source.resource`. That Workflow refers to the `run-tests` template. The `parameters` list copies one field of the event, `body.after`, into the first Workflow argument. The Workflow then clones exactly the pushed commit.

The Sensor creates the Workflow with its own ServiceAccount, `workflow-submitter`. The playground gave it a Role in `starfleet` that allows it to create Workflows and to read WorkflowTemplates.

Save this as `sensor-push-ci.yaml`:

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

Then check the result:

```sh
kubectl -n argo-events get eventbus,eventsource,sensor,pods
```

The output is:

```text
sensor.argoproj.io/push-ci created
NAME                           AGE
eventbus.argoproj.io/default   9m38s

NAME                                   AGE
eventsource.argoproj.io/push-webhook   46s

NAME                         AGE
sensor.argoproj.io/push-ci   45s
NAME                                              READY   STATUS    RESTARTS   AGE
controller-manager-9b4664947-c7n5p                1/1     Running   0          37m
eventbus-default-js-0                             3/3     Running   0          9m38s
push-ci-sensor-cvx6q-746cc4df7f-87c5r             1/1     Running   0          45s
push-webhook-eventsource-vjpw9-787d7b7ddf-9gnws   1/1     Running   0          46s
```

The bus, the event source and the sensor each run as a pod. The event source pod receives the push, publishes it to the bus, and the sensor pod takes it from there.

## Push and watch the run

Clone the repository through the port forward on your machine, change `VERSION`, and push to `main`:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-app.git
cd scout-app
echo 6.15.1 > VERSION
git commit -am "Bump VERSION to 6.15.1"
git push origin main
git rev-parse HEAD
```

The last command prints the commit ID. Then read the Workflows after about half a minute:

```sh
kubectl -n starfleet get workflows
NAME=$(kubectl -n starfleet get workflows -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet get workflow $NAME -o jsonpath='{.spec.arguments.parameters[0].value}{"\n"}'
kubectl -n starfleet logs $NAME -c main | grep -v INFO
```

The output is (your commit ID and name suffix are different):

```text
NAME            STATUS      AGE   MESSAGE
push-ci-4x9fc   Succeeded   25s   
d82df79e383b16852d703732c30795b1f61d9150
Checking VERSION
Tests passed for scout 6.15.1
```

The push created `push-ci-4x9fc` without any `kubectl create`. The `generateName` of the trigger produced the name, the argument `revision` holds the commit ID that `git rev-parse HEAD` printed, and the test log shows the new version `6.15.1`. Each component did one step: Gitea sent the webhook, the event source received it, the Sensor filtered it and created the Workflow, and the Workflow controller ran it.

The filter works as well. A push to another branch also reaches the event source, but the Sensor drops it. After `git checkout -b feature`, a commit and `git push origin feature`, the list of Workflows stays at the same single entry. When you are done, push `VERSION` back to `6.15.0` on `main`.

You now have the whole CI path: a push, an event, a filter, a Workflow, a test result in a pod log. The path has places that fail silently, so the list below names them.

## Common pitfalls

> [!WARNING]
> - A Sensor without the right Role creates nothing, and the error is only in the Sensor pod log. With only `create` on `workflows`, the `submit` operation fails with `workflowtemplates.argoproj.io "run-tests" is forbidden: User "system:serviceaccount:argo-events:workflow-submitter" cannot get resource "workflowtemplates"`. Read it with `kubectl -n argo-events logs -l sensor-name=push-ci`.
> - A one-pod JetStream `EventBus` needs `streamConfig` with `replicas: 1`. With the default of three stream replicas the pods log `replicas > 1 not supported in non-clustered mode`, and no event is delivered.

## Your mission: Start A Workflow From A Git Push With Argo Events

You can now receive a Git push with an EventSource, filter it with a Sensor and run a Workflow for the pushed commit. The mission gives you a `run-tests` WorkflowTemplate that fails and a webhook that nothing answers. You fix the template, create the EventSource and the Sensor, push a commit and prove that the push started a `Succeeded` Workflow.

Pause the playground, then start the lab and read the task:

```sh
astrona stop ats-018-playground-040-03
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-01
```

When the Workflow has succeeded, grade your work:

```sh
astrona submit -c sections/section-040/module-03/labs/lab-01
```

Then remove the lab and start the playground again:

```sh
astrona destroy ats-018-lab-040-03
astrona start ats-018-playground-040-03
```
