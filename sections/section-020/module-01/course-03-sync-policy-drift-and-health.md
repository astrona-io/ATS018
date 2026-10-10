# Sync Policy, Drift And Health

With a manual sync policy, Argo CD tells you about drift but leaves it in place, and a new commit waits until someone syncs it. That is not yet GitOps: the principle says the controller reconciles continuously. This part creates drift by hand, turns on automated sync with prune and self-heal, and changes the application only through Git. Then it breaks the application in Git, to show that `Synced` and `Healthy` answer two different questions.

## Drift with a manual policy

Change the live Deployment the way someone might during an incident, and ask Argo CD for a fresh comparison:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet-staging scale deploy/scout --replicas=3
argocd app get scout-staging --refresh
```

The end of the output is:

```text
Sync Status:        OutOfSync from main (0cfdbef)
Health Status:      Healthy

GROUP  KIND        NAMESPACE          NAME               STATUS     HEALTH   HOOK  MESSAGE
       Namespace                      starfleet-staging  Running    Synced         namespace/starfleet-staging created
       Service     starfleet-staging  scout              Synced     Healthy        service/scout created
apps   Deployment  starfleet-staging  scout              OutOfSync  Healthy        deployment.apps/scout created
```

The Deployment is `OutOfSync`, but `Healthy`: three replicas run fine, they are just not what Git says. `argocd app diff` shows the exact difference. The left side (`<`) is the live object and the right side (`>`) is Git:

```sh
argocd app diff scout-staging
```

You should see:

```text
===== apps/Deployment starfleet-staging/scout ======
137c137
<   replicas: 3
---
>   replicas: 1
```

Like `kubectl diff`, the command exits with `1` when it finds differences, so a script can use it as a check. With a manual policy, the drift stays until someone runs `argocd app sync`.

## Automated sync, prune and self-heal

The `automated` block of the sync policy makes the application controller sync on its own. It has two switches that people often confuse:

| Field | What it does when `true` |
| --- | --- |
| `automated` (present) | Syncs automatically when **Git** changes: a new commit makes the application `OutOfSync`, and the controller applies it |
| `selfHeal` | Also syncs when the **cluster** changes: drift such as a manual `kubectl scale` is reverted |
| `prune` | Deletes live objects that were removed from Git. Without it, they stay and the application stays `OutOfSync` |

In `application-scout-staging.yaml`, replace the `syncPolicy` block with this one:

```yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply it:

```sh
kubectl apply -f application-scout-staging.yaml
```

Within a few seconds, the Deployment is back at one replica: the drift you made earlier is reverted by the first automated sync. Now try to change the cluster again, and watch the replica count:

```sh
kubectl -n starfleet-staging scale deploy/scout --replicas=3
kubectl -n starfleet-staging get deploy scout
```

You should see something like:

```text
deployment.apps/scout scaled
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
scout   1/1     1            1           38s
```

On the playground, self-heal reverted the change in about a second. The application controller watches the live objects, so it does not wait for its timer to see drift. The Application's events show what it did; `kubectl` reads them like any other events:

```sh
kubectl -n argocd get events --field-selector involvedObject.name=scout-staging \
  --sort-by=.lastTimestamp -o custom-columns=REASON:.reason,MESSAGE:.message
```

The last lines look like this (shortened):

```text
OperationStarted     Initiated automated sync to '0cfdbef647534ab56a6d8061f0eef0a4dbeba19c'
ResourceUpdated      Updated sync status: Synced -> OutOfSync
ResourceUpdated      Updated health status: Healthy -> Progressing
OperationCompleted   Partial sync operation to 0cfdbef647534ab56a6d8061f0eef0a4dbeba19c succeeded
ResourceUpdated      Updated sync status: OutOfSync -> Synced
ResourceUpdated      Updated health status: Progressing -> Healthy
```

`Initiated automated sync` is the controller's own sync, and `Partial sync operation` means it applied only the objects that had drifted.

## Change the application through Git

From now on, the only way to change `scout-staging` is a commit. Clone the repository through the Git server's port on your machine. The user and password are in the URL only because this is a playground:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-deploy.git
cd scout-deploy
```

Add a ConfigMap to the staging overlay. Save this as `overlays/staging/notes.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scout-notes
data:
  owner: platform-team
```

In `overlays/staging/kustomization.yaml`, add `notes.yaml` under `resources`, below `../../base`. Commit and push, then ask for a refresh so you do not wait for the timer:

```sh
git add -A
git commit -m "Add scout-notes ConfigMap to staging"
git push
argocd app get scout-staging --refresh
```

After a few seconds, `argocd app get scout-staging` shows the new object:

```text
Sync Status:        Synced to main (658981f)
Health Status:      Healthy

GROUP  KIND        NAMESPACE          NAME         STATUS  HEALTH   HOOK  MESSAGE
       ConfigMap   starfleet-staging  scout-notes  Synced                 configmap/scout-notes unchanged
       Service     starfleet-staging  scout        Synced  Healthy        
apps   Deployment  starfleet-staging  scout        Synced  Healthy
```

The application is synced to the new commit (your ID differs). A ConfigMap has no health check, so its `HEALTH` column stays empty. Without `--refresh`, Argo CD finds the commit on its next timed poll of the repository, which takes a few minutes.

Now remove it again. Delete the file, remove the `notes.yaml` line from `overlays/staging/kustomization.yaml`, and push:

```sh
git rm overlays/staging/notes.yaml
git commit -am "Remove scout-notes from staging"
git push
argocd app get scout-staging --refresh
```

After a few seconds, `argocd app get scout-staging` shows:

```text
Sync Status:        Synced to main (10a1805)
Health Status:      Healthy

GROUP  KIND        NAMESPACE          NAME         STATUS     HEALTH   HOOK  MESSAGE
       ConfigMap   starfleet-staging  scout-notes  Succeeded  Pruned         pruned
       Service     starfleet-staging  scout        Synced     Healthy        service/scout unchanged
apps   Deployment  starfleet-staging  scout        Synced     Healthy        deployment.apps/scout unchanged
```

`Pruned` means the application controller deleted the ConfigMap because it left Git. Without `prune: true`, the ConfigMap would still exist, and the application would stay `OutOfSync` until someone deleted it.

## Synced, and still broken

Sync status compares Git with the cluster. It knows nothing about whether the pods work. Health status does: the application controller runs a health check for each object kind it knows, and a Deployment is `Degraded` when Kubernetes reports that its rollout passed the progress deadline. The `scout` base sets `progressDeadlineSeconds: 60`, so a bad rollout fails within a minute instead of the default ten.

Release an image tag that does not exist. In `overlays/staging/kustomization.yaml`, change `newTag: 6.15.0` to `newTag: 6.51.0`, then push and refresh:

```sh
git commit -am "Release scout 6.51.0 to staging"
git push
argocd app get scout-staging --refresh
```

The application is `Synced` and `Progressing`. Wait about a minute and look again:

```sh
argocd app get scout-staging
kubectl -n starfleet-staging get pods
```

You should see something like:

```text
Sync Status:        Synced to main (c2c4fd9)
Health Status:      Degraded

GROUP  KIND        NAMESPACE          NAME   STATUS  HEALTH    HOOK  MESSAGE
apps   Deployment  starfleet-staging  scout  Synced  Degraded        deployment.apps/scout unchanged
       Service     starfleet-staging  scout  Synced  Healthy         
NAME                     READY   STATUS             RESTARTS   AGE
scout-6bc6f87c95-wqdv9   0/1     ImagePullBackOff   0          80s
scout-859bff8ff5-qjgb7   1/1     Running            0          2m45s
```

`Synced` and `Degraded` together: the cluster is exactly what Git says, and what Git says does not work. The old pod still serves requests, because a rolling update keeps it until a new pod is ready. To see the health message for each object, ask the `argocd` tool for JSON:

```sh
argocd app get scout-staging -o json | jq -c '.status.resources[] | {kind,name,status,health}'
```

You should see:

```text
{"kind":"Service","name":"scout","status":"Synced","health":{"status":"Healthy"}}
{"kind":"Deployment","name":"scout","status":"Synced","health":{"status":"Degraded","message":"Deployment \"scout\" exceeded its progress deadline"}}
```

`kubectl -n argocd get application scout-staging -o yaml` does not show this: since Argo CD 3.0, the per-object health is no longer stored in the `Application` object. `kubectl` still shows the overall health of the application, while the `argocd` tool shows the health of each object.

Self-heal cannot help here, and `kubectl edit` would be reverted. The fix is a commit. Change `newTag` back to `6.15.0`, then push and wait:

```sh
git commit -am "Roll staging back to scout 6.15.0"
git push
argocd app get scout-staging --refresh
argocd app wait scout-staging --health
```

The application returns to `Synced` and `Healthy`, and the failing pod is removed.

```mermaid
stateDiagram-v2
    state "OutOfSync, Missing" as OM
    state "Synced, Progressing" as SP
    state "Synced, Healthy" as SH
    state "OutOfSync, Healthy" as OH
    state "Synced, Degraded" as SD
    [*] --> OM: Application created
    OM --> SP: sync
    SP --> SH: pods ready
    SH --> OH: manual change
    OH --> SH: self-heal
    SH --> SD: bad commit
    SD --> SH: fixing commit
```

The diagram shows the combinations of sync status and health status that `scout-staging` passed through, and the event that moved it each time.

You can now let Argo CD keep the cluster equal to Git on its own: `automated` follows new commits, `selfHeal` reverts drift, and `prune` removes what left Git. You have also seen that sync status and health status are separate checks, and that both kinds of problem are fixed in Git. The open question is how to deliver an application that is packaged as a Helm chart instead of a Kustomize overlay.

## Common pitfalls

> [!WARNING]
> - **Expecting `automated` alone to revert manual changes.** Drift in the cluster is only reverted with `selfHeal: true`.
> - **Removing a file from Git without `prune: true`.** The object stays in the cluster and the application stays `OutOfSync`.
> - **Reading `Synced` as "working".** Sync status only compares Git with the cluster; check the health status too.
> - **Looking for per-object health in the `Application` YAML.** Argo CD 3 keeps it out of the resource; use `argocd app get`.
> - **Fixing a `Degraded` application in the cluster.** Self-heal reverts it. Commit the fix.
