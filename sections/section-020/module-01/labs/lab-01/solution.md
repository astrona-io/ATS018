# Solution

Argo CD can only deliver what it can read, so the work has three parts: give Argo CD access to the repository, tell it what to deliver in an `Application`, and check the result.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-020/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: save the repository Secret

Argo CD reads repository credentials from Secrets in its own namespace that carry the label `argocd.argoproj.io/secret-type: repository`. The `url` in the Secret must match the `repoURL` of the `Application`.

Save this as `secret-repo-scout-deploy.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: repo-scout-deploy
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
  username: platform
  password: starfleet-gitops
```

Apply it:

```sh
kubectl apply -f secret-repo-scout-deploy.yaml
```

Without this Secret, the `repo-server` cannot clone the private repository, and the `Application` shows a `ComparisonError` condition.

## Step 2: save the Application

The `Application` says which Git path to render and which cluster and namespace to sync it to. `CreateNamespace=true` lets Argo CD create `starfleet-staging`. `automated` with `prune` and `selfHeal` makes Argo CD follow Git, delete what leaves Git and revert manual changes.

Save this as `application-scout-staging.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
    targetRevision: main
    path: overlays/staging
  destination:
    server: https://kubernetes.default.svc
    namespace: starfleet-staging
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

## Step 3: check the result

Read the sync status and the health status of the `Application`. Both can take up to a minute to settle while the pod starts:

```sh
kubectl -n argocd get application scout-staging
```

The columns `SYNC STATUS` and `HEALTH STATUS` must read `Synced` and `Healthy`. If the sync status is `Unknown`, read the conditions with `kubectl -n argocd get application scout-staging -o jsonpath='{.status.conditions}'`; a repository error there means Step 1 is wrong.

Send a request from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
```

The JSON response must contain `"version": "6.15.0"` and `"message": "staging"`.

## Step 4: check self-heal

Scale the Deployment by hand, then read the replica count again after a few seconds:

```sh
kubectl -n starfleet-staging scale deploy/scout --replicas=3
kubectl -n starfleet-staging get deploy scout
```

The application controller sees the drift and syncs again, so the Deployment returns to 1 replica. If it stays at 3, check that `selfHeal: true` is in the `Application` under `spec.syncPolicy.automated`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Common mistakes

- Applying the overlay with `kubectl apply -k`. The objects then have no Argo CD tracking annotation, and the grader rejects them.
- Writing the repository URL without `.git` in the Secret but with it in the `Application` (or the other way round). Argo CD then finds no credentials.
- Putting `selfHeal` or `prune` directly under `syncPolicy` instead of under `syncPolicy.automated`.
- Creating the namespace by hand instead of using `CreateNamespace=true`.
