# Solution

## Step 1: run the Pipeline and read the first failure

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

Create the run and read its status:

```sh
kubectl create -f pipelinerun-scout-release.yaml
kubectl -n starfleet get pipelinerun
kubectl -n starfleet get pipelinerun -o jsonpath='{.items[0].status.conditions[0].message}'
```

The run fails at once with the reason `PipelineValidationFailed`. The message ends with:

```text
invalid input params for task publish-image: missing values for these params which have no default values: [version]
```

The Task `publish-image` has a required parameter `version`, and the Pipeline does not set it. The Pipeline also lets `publish-image` start right after `fetch-source`, so a failing test would not stop the publish.

## Step 2: fix the Pipeline

In the Pipeline `scout-release`, change the Task `publish-image` so that it runs after `run-tests` and gets the version from `fetch-source`:

```yaml
    - name: publish-image
      runAfter:
        - run-tests
      taskRef:
        name: publish-image
      params:
        - name: version
          value: $(tasks.fetch-source.results.version)
```

Edit the Pipeline with `kubectl -n starfleet edit pipeline scout-release` and replace the `publish-image` entry. The Pipeline is not delivered by Argo CD, so `kubectl` is the right tool here.

## Step 3: give the pipeline Git credentials

The repository `scout-app` is private, and the run uses the service account `default`, which has no Git credentials. Tekton writes Git credentials into every step of a run when the run's service account lists a Secret of type `kubernetes.io/basic-auth` with the annotation `tekton.dev/git-0`. Save this as `secret-gitea-credentials.yaml`:

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

## Step 4: run again with the service account and read the next failure

Add a `taskRunTemplate` to `pipelinerun-scout-release.yaml`, before `workspaces`:

```yaml
  taskRunTemplate:
    serviceAccountName: scout-ci
```

Create a new run and read its logs after about 40 seconds:

```sh
kubectl create -f pipelinerun-scout-release.yaml
tkn -n starfleet pipelinerun logs --last
```

The `fetch-source` Task succeeds and `run-tests` fails. The end of the log is:

```text
[fetch-source : clone] Cloned http://gitea-http.gitea.svc:3000/starfleet/scout-app.git at 111d998, VERSION 6.15.0

task run-tests has failed: "step-test" exited with code 2: Error
[run-tests : test] sh: can't open 'test.sh': No such file or directory

Tasks Completed: 2 (Failed: 1, Cancelled 0), Skipped: 2
```

`publish-image` and `update-deploy` are skipped. This is the gate that Step 2 added.

## Step 5: fix the Task and the workspace

The step of `run-tests` starts in `/workspace/wrong`, a directory that does not exist, so it never finds `test.sh`. Change the line `workingDir: /workspace/wrong` with `kubectl -n starfleet edit task run-tests` to:

```yaml
      workingDir: $(workspaces.source.path)
```

A second cause hides behind the first. An `emptyDir` workspace belongs to one pod. `fetch-source` and `run-tests` run in two different pods, so `run-tests` never sees the clone. If you change only the working directory and run again, the same error returns. In the `PipelineRun`, replace `emptyDir: {}` with a `volumeClaimTemplate`, which creates one volume for the whole run:

```yaml
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 100Mi
```

Create a new run and read its logs after about 70 seconds:

```sh
kubectl create -f pipelinerun-scout-release.yaml
tkn -n starfleet pipelinerun logs --last
```

The log shows all four Tasks in order:

```text
[fetch-source : clone] Cloned http://gitea-http.gitea.svc:3000/starfleet/scout-app.git at 111d998, VERSION 6.15.0

[run-tests : test] Checking VERSION
[run-tests : test] Tests passed for scout 6.15.0

[publish-image : copy] Published registry.registry.svc:5000/starfleet/scout:6.15.0 (sha256:<digest>)

[update-deploy : commit-tag] Pushed <commit>: Deploy scout 6.15.0
```

The digest and the commit ID differ in your run.

## Step 6: check that Argo CD delivers the commit

Argo CD checks Git about every three minutes. Ask it to refresh now, then check the application, the rollout and the version:

```sh
argocd app get scout --refresh
argocd app wait scout --sync --health
kubectl -n starfleet rollout status deploy/scout
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet | grep version
```

The application is `Synced` and `Healthy`, and the request returns `"version": "6.15.0"`. If it still shows `6.14.0`, send the request again after a few seconds: the old pod can stay in the Service endpoints for a short time.

Do not fix the version with `kubectl set image` or `kubectl edit`. With self-heal on, Argo CD reverts the change, and Git would still say `6.14.0`. Do not remove `run-tests` from the Pipeline to make the run pass: the check reads the Pipeline and the order of the Tasks.

## Step 7: submit

```sh
astrona submit
```

The first check reads the Task, the Pipeline and the service account. The second check reads a `Succeeded` run and the times of its TaskRuns. The third check reads the registry tag and compares the newest commit in `scout-deploy` with the `deploy-commit` result of a run. The fourth check reads the Argo CD `Application` and sends a request from `shuttle`.
