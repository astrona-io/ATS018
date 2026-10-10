# App Of Apps

An `Application` is a Kubernetes object, so it can live in Git like any other manifest. That simple fact is the whole idea of the app of apps pattern: keep every `Application` manifest in a folder, and create one parent `Application` that delivers the folder. This part sets it up for three services and then looks at what the pattern does not solve.

## The parent Application

The folder `argocd-apps/` in the `platform-apps` repository holds three files, `scout.yaml`, `probe.yaml` and `bridge.yaml`. Each one is a complete `Application` that delivers one folder under `apps/` into the namespace `starfleet` with automated sync. Here is `scout.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
    targetRevision: main
    path: apps/scout
  destination:
    server: https://kubernetes.default.svc
    namespace: starfleet
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

The parent is an ordinary `Application` whose path is that folder and whose destination namespace is `argocd`, because that is where `Application` objects live.

<!-- astrona:playground:renew -->

Save this as `application-platform-apps.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
    targetRevision: main
    path: argocd-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply it:

```sh
kubectl apply -f application-platform-apps.yaml
```

Then check the result after about half a minute. Log the `argocd` tool in first if you have not (`argocd login 127.0.0.1:8080 --username admin --insecure` with the password from the Secret):

```sh
argocd app list
argocd app get platform-apps
```

You should see something like this (the `argocd app list` columns are shortened to fit):

```text
NAME                  NAMESPACE  PROJECT  STATUS  HEALTH   SYNCPOLICY  PATH
argocd/bridge         starfleet  default  Synced  Healthy  Auto-Prune  apps/bridge
argocd/platform-apps  argocd     default  Synced  Healthy  Auto-Prune  argocd-apps
argocd/probe          starfleet  default  Synced  Healthy  Auto-Prune  apps/probe
argocd/scout          starfleet  default  Synced  Healthy  Auto-Prune  apps/scout
...
Sync Status:        Synced to main (57ee69e)
Health Status:      Healthy

GROUP        KIND         NAMESPACE  NAME    STATUS  HEALTH  HOOK  MESSAGE
argoproj.io  Application  argocd     scout   Synced                application.argoproj.io/scout unchanged
argoproj.io  Application  argocd     probe   Synced                application.argoproj.io/probe unchanged
argoproj.io  Application  argocd     bridge  Synced                application.argoproj.io/bridge unchanged
```

One `kubectl apply` produced four applications. The parent synced three `Application` objects, and each child then synced its own service into `starfleet`. `kubectl -n starfleet get deploy` lists `bridge`, `probe` and `scout` next to `shuttle`.

## Where the pattern stops helping

Look at the `HEALTH` column of the parent's objects: it is empty. Argo CD does not judge the health of an `Application` object by default, so the parent stays `Healthy` even when a child is `Degraded`. You must watch the children, not the parent.

The bigger limit is that nothing is generated. Each child is a full manifest written by hand. A fourth service is a fourth file that copies the first three and changes three lines. Two environments double the files. The pattern moves the copies into Git, which is better than creating them with `kubectl`, but it does not remove them.

Deleting the parent also behaves in a way people do not expect. Delete it with `kubectl`:

```sh
kubectl delete -f application-platform-apps.yaml
kubectl -n argocd get applications
```

You should see something like:

```text
application.argoproj.io "platform-apps" deleted from argocd namespace
NAME     SYNC STATUS   HEALTH STATUS
bridge   Synced        Healthy
probe    Synced        Healthy
scout    Synced        Healthy
```

The children are still there. An `Application` deletes the objects it delivered only when it carries the finalizer `resources-finalizer.argocd.argoproj.io`, and the parent here has none. Without the finalizer, deleting an `Application` deletes only that object and leaves everything it created running. Add the finalizer to `metadata.finalizers` when you want a cascading delete; leave it out when you want to stop managing something without removing it.

You can now bootstrap several applications from one parent and know its limits: the parent does not report its children's health, every child is hand-written, and a delete only cascades with a finalizer. The open question is how to generate the children instead of writing them. The three child applications are still running, and the next part reuses them.

## Common pitfalls

> [!WARNING]
> - **Giving the parent a destination other than `argocd`.** `Application` objects must be created in the `argocd` namespace.
> - **Watching only the parent.** Its health ignores the children's health by default.
> - **Expecting a delete to cascade.** Without `resources-finalizer.argocd.argoproj.io`, deleting an `Application` leaves its objects running.
> - **Copying child manifests for each new service and environment.** That is the job of an `ApplicationSet`.
