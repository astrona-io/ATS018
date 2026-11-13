# Sync Failures, Waves And Hooks

When rendering works, Argo CD has a desired state and tries to apply it. The Kubernetes API server can still refuse an object, and Argo CD then reports a failed sync operation. This part reads such a failure on `scout-reject`, fixes it in Git, and deals with an automated retry that keeps trying the old commit. It then uses the sync machinery on purpose: a `PreSync` hook that runs before everything else, and a sync wave that puts one object before the others.

## A manifest the API server rejects

`scout-reject` is `OutOfSync` and its health looks fine. The object table shows why:

<!-- astrona:playground:renew -->

```sh
argocd app get scout-reject
```

The end of the output is:

```text
Sync Status:        OutOfSync from main (3ea1193)
Health Status:      Healthy

GROUP  KIND        NAMESPACE         NAME   STATUS     HEALTH   HOOK  MESSAGE
       Service     starfleet-reject  scout  Synced     Healthy        service/scout unchanged
apps   Deployment  starfleet-reject  scout  OutOfSync  Missing        Deployment.apps "scout" is invalid: spec.template.spec.containers[0].ports[0].containerPort: Invalid value: 99999: must be between 1 and 65535, inclusive
```

The Service was applied; the Deployment was not, and it is `Missing`. The message is the API server's own validation error, passed on by the application controller: the container port `99999` is out of range. The sync operation holds the same message, plus something new:

```sh
kubectl -n argocd get application scout-reject \
  -o jsonpath='{.status.operationState.phase}: {.status.operationState.message}{"\n"}'
```

You should see something like:

```text
Running: one or more synchronization tasks completed unsuccessfully, reason: Deployment.apps "scout" is invalid: spec.template.spec.containers[0].ports[0].containerPort: Invalid value: 99999: must be between 1 and 65535, inclusive. Retrying attempt #4 at 4:07PM.
```

The phase is `Running`, not `Failed`. On the playground, Argo CD 3.5 retried the failed automated sync on its own, with a growing delay between attempts. The application's `syncPolicy` sets no `retry` block, so this is the installed default.

## Fix it in Git, then stop the old retry

The cause is in the files, so the fix is a commit. Clone the repository, correct the port, and push:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-faults.git
cd scout-faults
sed -i.bak 's/containerPort: 99999/containerPort: 9898/' reject/scout.yaml && rm reject/scout.yaml.bak
git commit -am "Fix the container port of scout"
git push
argocd app get scout-reject --refresh
```

On the playground, the application stayed `OutOfSync` with the same error for minutes after the push. The reason is in the operation:

```sh
kubectl -n argocd get application scout-reject \
  -o jsonpath='{.status.operationState.operation.sync.revision}{"\n"}'
```

You should see:

```text
3ea119352731a4f7a65acbb45557759484cf3bfc
```

That is the old commit. A running operation keeps the revision it started with, so every retry applies the broken manifest again, and the new commit waits until the retries give up. Stop the operation, and the next automated sync picks up the new commit:

```sh
argocd app terminate-op scout-reject
argocd app wait scout-reject --sync --health
```

The end of the output is:

```text
Sync Status:        Synced to main (db4345f)
Health Status:      Healthy

GROUP  KIND        NAMESPACE         NAME   STATUS  HEALTH   HOOK  MESSAGE
apps   Deployment  starfleet-reject  scout  Synced  Healthy        deployment.apps/scout unchanged
       Service     starfleet-reject  scout  Synced  Healthy
```

Synced to the new commit (your commit IDs differ). The rule to take away: after fixing a failed sync in Git, check which revision the operation is working on, and terminate it if it is the old one.

## Ordering a sync with hooks and waves

Some objects must exist or finish before others. A database schema migration must run before the new version of the application starts; a ConfigMap must exist before the pods that read it. Argo CD has two tools for this.

A **resource hook** is an object with the annotation `argocd.argoproj.io/hook`. It is not part of the normal apply. It runs at a fixed point of the sync: `PreSync` before anything else, `Sync` with the others, `PostSync` after everything is healthy, and `SyncFail` when the sync fails. A hook is usually a Job, and a failed `PreSync` Job stops the sync before anything is changed.

A **sync wave** is a number in the annotation `argocd.argoproj.io/sync-wave`. Objects without it are in wave `0`. Argo CD applies lower waves first and waits until every object of a wave is healthy before it starts the next one.

Add both to the `path` folder, the source of the healthy `scout-path` application. Save this as `path/migrate.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: scout-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: busybox:1.37
          command: ["sh", "-c", "echo migrating the scout schema; sleep 5; echo done"]
```

`hook-delete-policy: BeforeHookCreation` deletes the previous Job before the next sync creates it again, so every sync runs a fresh Job under the same name.

Save this as `path/settings.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scout-settings
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
data:
  PODINFO_UI_MESSAGE: waves
```

The wave is a string in quotes, because annotation values are always strings. Save this as `path/kustomization.yaml`, replacing the file:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - settings.yaml
  - migrate.yaml
  - scout.yaml
```

Commit, push, and wait for the sync:

```sh
git add -A
git commit -m "Add a PreSync migration Job and a settings ConfigMap in wave -1"
git push
argocd app get scout-path --refresh
argocd app wait scout-path --sync --health
argocd app get scout-path
```

The end of the output is:

```text
Sync Status:        Synced to main (568181d)
Health Status:      Healthy

GROUP  KIND        NAMESPACE       NAME            STATUS     HEALTH   HOOK     MESSAGE
batch  Job         starfleet-path  scout-migrate   Succeeded  Synced   PreSync  Reached expected number of succeeded pods
       ConfigMap   starfleet-path  scout-settings  Synced                       configmap/scout-settings created
       Service     starfleet-path  scout           Synced     Healthy           service/scout unchanged
apps   Deployment  starfleet-path  scout           Synced     Healthy           deployment.apps/scout unchanged
```

The `HOOK` column marks the Job as a `PreSync` hook, and its status is `Succeeded`, not `Synced`: hooks are run, not kept in sync. The order was: the hook Job, then wave `-1` (the ConfigMap), then wave `0` (the Service and the Deployment). The Job's log proves it ran:

```sh
kubectl -n starfleet-path logs job/scout-migrate
```

You should see:

```text
migrating the scout schema
done
```

You can now read a sync failure from the object messages and the operation, recognise an automated retry that is stuck on an old commit, and order the objects of a sync with hooks and waves. The open question is the application that is `OutOfSync` although nothing failed at all.

## Common pitfalls

> [!WARNING]
> - **Reading the sync status only.** A rejected object shows `OutOfSync` and `Missing`; the reason is in its message column.
> - **Pushing a fix and waiting.** A retrying operation keeps its old revision. Check `operationState.operation.sync.revision` and use `argocd app terminate-op`.
> - **Writing the sync wave as a number.** Annotation values must be strings: `"-1"`, not `-1`.
> - **A `PreSync` hook that fails.** The sync stops before any other object is applied; read the Job's log, fix it in Git and sync again.
