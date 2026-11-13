# Solution

Add these three files in the cloned repository:

`path/migrate.yaml`:

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

`path/settings.yaml`:

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

`path/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - settings.yaml
  - migrate.yaml
  - scout.yaml
```

Commit and reconcile:

```sh
git add path
git commit -m "Run migration before the settings wave"
git push
kubectl -n argocd annotate application scout-path argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application scout-path -w
```

When the Application is Synced and Healthy, stop the watch and inspect the result:

```sh
kubectl -n argocd get application scout-path -o jsonpath='{.status.operationState.syncResult.resources}'
kubectl -n starfleet-path logs job/scout-migrate
kubectl -n starfleet-path get configmap scout-settings -o yaml
```

The operation records the hook as `PreSync` and `Succeeded`. Its log ends in `done`. The hook finishes before ordinary sync resources; the ConfigMap is in wave `-1`, ahead of the Service and Deployment in wave `0`. A later sync replaces the Job because of `BeforeHookCreation`.
