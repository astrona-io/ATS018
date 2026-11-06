# Start The Pipeline From A Git Push

The `scout-push` `EventListener` is running in `starfleet`, with its `cel` filter, its `TriggerBinding` and its `TriggerTemplate`, but nothing has sent it a request yet. This part sends one by hand to prove the filter, connects the Git server's webhook, and pushes one change that ends as the new version of `scout`. It closes with where to look when a push creates no run.

## Test the filter before the Git server

A webhook is an HTTP (Hypertext Transfer Protocol) request the Git server sends on every push. Before you connect the Git server, check that the filter works. Send a push event for another branch from `shuttle`, with the same header and JSON fields the Git server would send:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -X POST -H 'Content-Type: application/json' \
  -H 'X-Gitea-Event: push' -d '{"ref":"refs/heads/dev","after":"abc"}' http://el-scout-push.starfleet.svc:8080
tkn -n starfleet pipelinerun list
```

The `curl` line of the output is:

```text
{"eventListener":"scout-push","namespace":"starfleet","eventListenerUID":"5329dfda-6315-404d-8916-b49ec95b521e","eventID":"46fdf7fd-4800-4572-b7a0-0c23e4086294"}
```

The listener accepted the request and gave it an event ID, but `tkn pipelinerun list` shows no new run: the `cel` interceptor dropped the event, because `ref` is not `refs/heads/main`. The listener answers with status 202 and this JSON body for every request it takes, without waiting for the interceptors, so the reply only proves that the request arrived.

## Connect the webhook and push a change

The webhook is a setting of the Git server. In this playground the Git server is Gitea, and one request to its HTTP API adds a webhook to `scout-app` that sends push events to the listener:

```sh
curl -s -u platform:starfleet-gitops -X POST -H 'Content-Type: application/json' \
  http://127.0.0.1:3000/api/v1/repos/starfleet/scout-app/hooks \
  -d '{"type":"gitea","active":true,"events":["push"],"config":{"url":"http://el-scout-push.starfleet.svc:8080","content_type":"json"}}' \
  -o /dev/null -w "%{http_code}\n"
```

The output `201` means the webhook was created. The URL is the in-cluster Service address of the listener, because the Git server's pod sends the request from inside the cluster. Now release `6.15.0` the way a developer would: clone `scout-app`, change `VERSION`, commit and push.

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

The labels show that the `EventListener` `scout-push` created the run through the trigger `push-to-main`, and the `revision` param holds the full ID of the pushed commit. The `triggers-eventid` label is the same ID the listener returned to the Git server, so one request can be matched to one run. The pipeline cloned exactly that commit, published `6.15.0`, and pushed `47429b5` to `scout-deploy`.

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

## When a push creates no run

A push that produces nothing has failed at one of three places, and each one leaves its own evidence. Work through them in order, from the Git server towards the run:

```sh
kubectl -n starfleet get eventlistener scout-push
kubectl -n starfleet logs -l eventlistener=scout-push --tail=50
tkn -n starfleet pipelinerun list
```

Start at the Git server. It keeps a record of each delivery with the response it got, and a webhook URL that points outside the cluster, or at a wrong Service name, fails there with no `202`. When the delivery got a `202`, read the listener log. For every trigger that passed its interceptors, the `el-` pod writes one line that starts with `ResolvedParams` and shows the params it read from the request, so a missing `ResolvedParams` line after a delivered push means the `cel` filter dropped it; compare the header and the `ref` of the real request with the filter. A `ResolvedParams` line followed by an error means the pod could not create the run: a template that refers to a Pipeline that does not exist, or a service account without the Triggers roles. An error without that line points at the bindings, for example a param that names a missing body field. A run that exists but fails is no longer a Triggers problem: `tkn pipelinerun describe` and `logs` show which task failed.

You can now start a pipeline from a Git push with an `EventListener`, a `TriggerBinding` and a `TriggerTemplate`, filter events with the `cel` interceptor, and prove a release from the push to the version that `shuttle` receives. The flow has two status commands worth remembering: `tkn pipelinerun describe` for the CI half and `argocd app get` for the delivery half.

## Common pitfalls

> [!WARNING]
> - **A filter on the wrong header.** Each Git server names its event header differently. Check a real request before you trust the filter.
> - **A webhook URL the Git server cannot reach.** The webhook is sent from the Git server's pod, so use the in-cluster Service address of the `EventListener`.
> - **Reading "accepted" as "started".** The listener answers with an event ID even when an interceptor drops the event. Check `tkn pipelinerun list`.
> - **Looking for the fault in the wrong place.** The Git server shows whether the delivery arrived, the listener log shows whether the run was created, and `tkn` shows whether it passed. Start at the Git server.

## Your mission: Create PipelineRuns From JSON Requests With Tekton Triggers

You can now bind request fields to run params and give a listener permission to create runs. The mission asks you to repair an existing listener, extract two fields and prove that its requests produce successful runs.

Pause the playground, then start the lab:

```sh
astrona stop ats-018-playground-040-02
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-02/labs/lab-02
```

In another host terminal, watch the checks as you work:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-02/labs/lab-02
```

The watch grades every few seconds and records nothing. Once all checks pass, stop the watch with Ctrl-C and submit once; a plain submission finishes the attempt and deletes the lab:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-02/labs/lab-02
```

If the lab is still present, remove it, then resume the playground:

```sh
astrona destroy ats-018-lab-040-02-02
astrona start ats-018-playground-040-02
```
