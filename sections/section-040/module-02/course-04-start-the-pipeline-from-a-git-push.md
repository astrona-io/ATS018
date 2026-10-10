# Start The Pipeline From A Git Push

Continuous integration means every change runs the pipeline, without anyone starting it. The Git server can send an HTTP request, a webhook, on every push. Tekton Triggers turns that request into a PipelineRun. This part builds the three Triggers objects, connects the webhook, and pushes one change that ends as the new version of `scout`.

## Three objects between a request and a run

Tekton Triggers is a separate Tekton project with its own controller. It adds three custom resources:

- An **`EventListener`** is the Tekton Triggers object that receives a webhook and creates a run from it. For each `EventListener`, the Triggers controller starts a Deployment and a Service called `el-<name>` that accept HTTP requests on port `8080`.
- A **`TriggerBinding`** reads values out of the request, such as the commit ID from the JSON body, and names them as params.
- A **`TriggerTemplate`** holds the resource to create, here a PipelineRun, with `$(tt.params.<name>)` placeholders for those params.

An `EventListener` can also run **interceptors** first. An interceptor checks or filters the request before any run is created. The `cel` interceptor evaluates an expression in the Common Expression Language (CEL) against the headers and body, and drops the request when the expression is false.

## Permissions for the EventListener

The `el-` pod reads the Triggers objects and creates PipelineRuns, so it needs its own service account with rights to do that. Tekton Triggers ships two ClusterRoles for this: `tekton-triggers-eventlistener-roles` for the namespace, and `tekton-triggers-eventlistener-clusterroles` for the cluster-wide objects such as the interceptors.

<!-- astrona:playground:renew -->

Save this as `rbac-scout-triggers.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: scout-triggers
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: scout-triggers
  namespace: starfleet
subjects:
  - kind: ServiceAccount
    name: scout-triggers
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: tekton-triggers-eventlistener-roles
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: scout-triggers
subjects:
  - kind: ServiceAccount
    name: scout-triggers
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: tekton-triggers-eventlistener-clusterroles
```

This service account only creates runs. The runs themselves still use `scout-ci`, which holds the Git credentials.

## The binding, the template and the listener

The Git server sends a JSON body on each push. Its field `after` is the commit ID the branch points to after the push, and its field `ref` is the branch, for example `refs/heads/main`. The binding takes `after` as the param `revision`.

Save this as `triggerbinding-scout-push.yaml`:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: scout-push
  namespace: starfleet
spec:
  params:
    - name: revision
      value: $(body.after)
```

The template creates the same PipelineRun you created by hand, with the pushed commit as the `revision` param. Building from the exact commit, not from `main`, means a second push during the run cannot change what this run builds.

Save this as `triggertemplate-scout-release.yaml`:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: scout-release
  namespace: starfleet
spec:
  params:
    - name: revision
      description: The commit ID that was pushed
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: scout-release-
      spec:
        pipelineRef:
          name: scout-release
        params:
          - name: revision
            value: $(tt.params.revision)
        taskRunTemplate:
          serviceAccountName: scout-ci
        workspaces:
          - name: source
            emptyDir: {}
```

The listener ties them together. Its `cel` filter accepts only push events (the Git server sets the header `X-Gitea-Event: push`) to the `main` branch.

Save this as `eventlistener-scout-push.yaml`:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: scout-push
  namespace: starfleet
spec:
  serviceAccountName: scout-triggers
  triggers:
    - name: push-to-main
      interceptors:
        - ref:
            name: cel
          params:
            - name: filter
              value: "header.match('X-Gitea-Event', 'push') && body.ref == 'refs/heads/main'"
      bindings:
        - ref: scout-push
      template:
        ref: scout-release
```

Apply all four files:

```sh
kubectl apply -f rbac-scout-triggers.yaml -f triggerbinding-scout-push.yaml \
  -f triggertemplate-scout-release.yaml -f eventlistener-scout-push.yaml
```

Then check the result after about 20 seconds:

```sh
kubectl -n starfleet get eventlistener
kubectl -n starfleet get deploy,svc -l eventlistener=scout-push
```

The output is:

```text
NAME         ADDRESS                                                 AVAILABLE   REASON                     READY   REASON
scout-push   http://el-scout-push.starfleet.svc.cluster.local:8080   True        MinimumReplicasAvailable   True    
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/el-scout-push   1/1     1            1           21s

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
service/el-scout-push   ClusterIP   10.96.150.188   <none>        8080/TCP,9000/TCP   21s
```

The Triggers controller created the Deployment and the Service `el-scout-push`, and the `ADDRESS` column shows the URL the webhook must call.

Before you connect the Git server, check that the filter works. Send a push event for another branch from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -X POST -H 'Content-Type: application/json' \
  -H 'X-Gitea-Event: push' -d '{"ref":"refs/heads/dev","after":"abc"}' http://el-scout-push.starfleet.svc:8080
tkn -n starfleet pipelinerun list
```

The `curl` line of the output is:

```text
{"eventListener":"scout-push","namespace":"starfleet","eventListenerUID":"5329dfda-6315-404d-8916-b49ec95b521e","eventID":"46fdf7fd-4800-4572-b7a0-0c23e4086294"}
```

The listener accepted the request and gave it an event ID, but `tkn pipelinerun list` shows no new run: the `cel` interceptor dropped the event, because `ref` is not `refs/heads/main`.

## Connect the webhook and push a change

The webhook is a setting of the Git server. In this playground the Git server is Gitea, and one request to its HTTP API adds a webhook to `scout-app` that sends push events to the listener:

```sh
curl -s -u platform:starfleet-gitops -X POST -H 'Content-Type: application/json' \
  http://127.0.0.1:3000/api/v1/repos/starfleet/scout-app/hooks \
  -d '{"type":"gitea","active":true,"events":["push"],"config":{"url":"http://el-scout-push.starfleet.svc:8080","content_type":"json"}}' \
  -o /dev/null -w "%{http_code}\n"
```

The output `201` means the webhook was created. Now release `6.15.0` the way a developer would: clone `scout-app`, change `VERSION`, commit and push.

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-app.git
cd scout-app
echo 6.15.0 > VERSION
git commit -am "Release scout 6.15.0"
git push
```

The last lines of the output are:

```text
To http://127.0.0.1:3000/starfleet/scout-app.git
   fe01e32..3293300  main -> main
```

Your commit IDs differ. The push is the only thing you do. Everything after it happens on its own:

```mermaid
sequenceDiagram
    participant G as Git server
    participant E as EventListener
    participant P as PipelineRun
    participant R as registry
    participant D as scout-deploy
    participant A as Argo CD
    G->>E: push webhook
    E->>P: create run for commit
    P->>R: copy image to new tag
    P->>D: commit new tag
    A->>D: refresh, see commit
    A->>A: sync Deployment
```

The diagram shows the webhook reaching the `EventListener`, the PipelineRun writing to the registry and to `scout-deploy`, and Argo CD picking up the commit and syncing the Deployment.

## Follow one change end to end

Look for the run the push created, and follow its log until it ends:

```sh
tkn -n starfleet pipelinerun list
tkn -n starfleet pipelinerun logs --last -f
tkn -n starfleet pipelinerun describe --last
```

The output is (the `list` part is shortened to the new run, and the `describe` part to the labels, the status and the params):

```text
NAME                  STARTED          DURATION   STATUS
scout-release-887sn   10 seconds ago   ---        Running
[fetch-source : clone] Cloned http://gitea-http.gitea.svc:3000/starfleet/scout-app.git at 3293300, VERSION 6.15.0

[publish-image : copy] Published registry.registry.svc:5000/starfleet/scout:6.15.0 (sha256:ec73780a8425f59ea49f5bc8cdff0d598805a224fbaa1f86c67a244f250fa9da)

[update-deploy : commit-tag] Pushed 47429b5: Deploy scout 6.15.0

Name:              scout-release-887sn
Namespace:         starfleet
Pipeline Ref:      scout-release
Service Account:   scout-ci
Labels:
 tekton.dev/pipeline=scout-release
 triggers.tekton.dev/eventlistener=scout-push
 triggers.tekton.dev/trigger=push-to-main
 triggers.tekton.dev/triggers-eventid=27352905-40b9-42b2-bea3-afb0835801e1
...
STARTED          DURATION   STATUS
15 seconds ago   15s        Succeeded
...
Params

 NAME       VALUE
 revision   3293300fb027583f7be47d664c3c3568f2112d28
```

The labels show that the `EventListener` `scout-push` created the run through the trigger `push-to-main`, and the `revision` param holds the full ID of the pushed commit. The pipeline cloned exactly that commit, published `6.15.0`, and pushed `47429b5` to `scout-deploy`.

Now follow the commit through Argo CD to the running pods:

```sh
argocd app get scout --refresh
argocd app wait scout --sync --health
kubectl -n starfleet rollout status deploy/scout
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet | grep -E '"(version|hostname)"'
```

The output is (the `argocd app get` part is shortened to its status lines):

```text
Sync Status:        OutOfSync from main (47429b5)
Health Status:      Healthy
...
Sync Status:        Synced to main (47429b5)
Health Status:      Healthy
deployment "scout" successfully rolled out
  "hostname": "scout-5c47cfdbff-5mbf2",
  "version": "6.15.0",
```

Argo CD first reported the commit as `OutOfSync`, then synced it, and the new pod answers with `6.15.0`. One push to the source repository produced a PipelineRun, a new image tag, a commit in the GitOps repository and an Argo CD sync, and no step outside Argo CD touched the Deployment.

You can now start a pipeline from a Git push with an `EventListener`, a `TriggerBinding` and a `TriggerTemplate`, filter events with the `cel` interceptor, and prove a release from the push to the version that `shuttle` receives. The flow has two status commands worth remembering: `tkn pipelinerun describe` for the CI half and `argocd app get` for the delivery half.

## Common pitfalls

> [!WARNING]
> - **An `EventListener` without a service account that has the Triggers roles.** The `el-` pod cannot read the bindings or create runs. Bind both `tekton-triggers-eventlistener-roles` and `tekton-triggers-eventlistener-clusterroles`.
> - **Building from `main` instead of the pushed commit.** A later push can change what the run builds. Bind `$(body.after)` and clone that commit.
> - **A filter on the wrong header.** Each Git server names its event header differently. Check a real request before you trust the filter.
> - **A webhook URL the Git server cannot reach.** The webhook is sent from the Git server's pod, so use the in-cluster Service address of the `EventListener`.
> - **Reading "accepted" as "started".** The listener answers with an event ID even when an interceptor drops the event. Check `tkn pipelinerun list`.
