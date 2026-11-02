# Solution

## Step 1: write the Pipeline

The three Tasks already exist. Save this as `pipeline-scout-release.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: scout-release
  namespace: starfleet
spec:
  params:
    - name: revision
      type: string
      default: main
  workspaces:
    - name: source
  tasks:
    - name: fetch-source
      taskRef:
        name: fetch-source
      params:
        - name: url
          value: http://gitea-http.gitea.svc:3000/starfleet/scout-app.git
        - name: revision
          value: $(params.revision)
      workspaces:
        - name: source
          workspace: source
    - name: publish-image
      taskRef:
        name: publish-image
      params:
        - name: version
          value: $(tasks.fetch-source.results.version)
    - name: update-deploy
      runAfter:
        - publish-image
      taskRef:
        name: update-deploy
      params:
        - name: version
          value: $(tasks.fetch-source.results.version)
  results:
    - name: deploy-commit
      value: $(tasks.update-deploy.results.commit)
```

`publish-image` uses a result of `fetch-source`, so Tekton starts it after the clone. `update-deploy` takes no result from `publish-image`, so it needs `runAfter` to wait for the publish.

Apply it:

```sh
kubectl apply -f pipeline-scout-release.yaml
```

## Step 2: run it and read the first failure

Save this as `pipelinerun-scout-release.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: scout-release-
  namespace: starfleet
spec:
  pipelineRef:
    name: scout-release
  workspaces:
    - name: source
      emptyDir: {}
```

Create the run and read its logs after about 40 seconds:

```sh
kubectl create -f pipelinerun-scout-release.yaml
tkn -n starfleet pipelinerun logs --last
```

The run fails in `fetch-source` with `fatal: could not read Username for 'http://gitea-http.gitea.svc:3000'`. The repository is private, and the run uses the service account `default`, which has no Git credentials. `publish-image` and `update-deploy` are skipped.

## Step 3: give the pipeline Git credentials

Tekton writes Git credentials into every step of a run when the run's service account lists a Secret of type `kubernetes.io/basic-auth` with the annotation `tekton.dev/git-0`. Save this as `secret-gitea-credentials.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitea-credentials
  namespace: starfleet
  annotations:
    tekton.dev/git-0: http://gitea-http.gitea.svc:3000
type: kubernetes.io/basic-auth
stringData:
  username: platform
  password: starfleet-gitops
```

Save this as `serviceaccount-scout-ci.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: scout-ci
  namespace: starfleet
secrets:
  - name: gitea-credentials
```

Apply both:

```sh
kubectl apply -f secret-gitea-credentials.yaml -f serviceaccount-scout-ci.yaml
```

## Step 4: run the Pipeline with the service account

Change `pipelinerun-scout-release.yaml` so that the `spec` has a `taskRunTemplate` field before `workspaces`:

```yaml
  taskRunTemplate:
    serviceAccountName: scout-ci
```

Create a new run and read its logs after about 40 seconds:

```sh
kubectl create -f pipelinerun-scout-release.yaml
tkn -n starfleet pipelinerun logs --last
```

The last lines of the log are:

```text
[publish-image : copy] Published registry.registry.svc:5000/starfleet/scout:6.15.0 (sha256:<digest>)

[update-deploy : commit-tag] Pushed <commit>: Deploy scout 6.15.0
```

The `fetch-source` Task read `VERSION` from `scout-app`, `publish-image` copied the image to the tag `6.15.0`, and `update-deploy` pushed the commit to `scout-deploy`. The digest and the commit ID differ in your run.

## Step 5: check that Argo CD delivers the commit

Argo CD checks Git about every three minutes. Ask it to refresh now, then check the application, the rollout and the version:

```sh
argocd app get scout --refresh
argocd app wait scout --sync --health
kubectl -n starfleet rollout status deploy/scout
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet | grep version
```

The application is `Synced` and `Healthy`, and the request returns `"version": "6.15.0"`. If it still shows `6.14.0`, send the request again after a few seconds: the old pod can stay in the Service endpoints for a short time.

Do not fix the version with `kubectl set image` or `kubectl edit`. With self-heal on, Argo CD reverts the change, and Git would still say `6.14.0`.

## Step 6: submit

```sh
astrona submit
```

The first check reads the Pipeline, the service account and a `Succeeded` run. The second check reads the registry tag and compares the newest commit in `scout-deploy` with the `deploy-commit` result of a run. The third check reads the Argo CD `Application` and sends a request from `shuttle`.
