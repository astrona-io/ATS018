# Commit The New Tag With Git Credentials

The new image exists, but the cluster only changes when Git changes. This part writes the Task that sets the new tag in the GitOps repository and pushes a commit. The repository is private, so the Task first fails, and then gets credentials through a Secret and a service account. The part ends with Argo CD serving the new tag.

## A Task that commits the tag

The GitOps repository `scout-deploy` sets the image tag in its `kustomization.yaml`:

```yaml
images:
  - name: registry.registry.svc:5000/starfleet/scout
    newTag: 6.14.0
```

The Task clones the repository, replaces the `newTag` line, commits, and pushes to `main`. If the tag is already the one asked for, it skips the commit, so running it twice is safe.

<!-- astrona:playground:renew -->

Save this as `task-update-deploy.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: update-deploy
  namespace: starfleet
spec:
  params:
    - name: version
      type: string
      description: The image tag to deploy
    - name: url
      type: string
      default: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
  results:
    - name: commit
      description: The commit ID pushed to the GitOps repository
  steps:
    - name: commit-tag
      image: alpine/git:2.52.0
      workingDir: /tmp/scout-deploy
      script: |
        #!/bin/sh
        set -eu
        git clone --quiet "$(params.url)" .
        sed -i "s/newTag: .*/newTag: $(params.version)/" kustomization.yaml
        if git diff --quiet; then
          echo "scout-deploy already uses $(params.version)"
        else
          git -c user.name=tekton -c user.email=tekton@starfleet.local \
            commit --quiet -am "Deploy scout $(params.version)"
          git push --quiet origin HEAD:main
          echo "Pushed $(git rev-parse --short HEAD): Deploy scout $(params.version)"
        fi
        printf '%s' "$(git rev-parse HEAD)" > "$(results.commit.path)"
```

The commit message names the version, and the author is `tekton`, so the history of `scout-deploy` shows which commits came from the pipeline. The Task needs no workspace, because no other Task reads its files.

Apply it, and run it for version `6.14.1`:

```sh
kubectl apply -f task-update-deploy.yaml
tkn -n starfleet task start update-deploy -p version=6.14.1 --use-param-defaults --showlog
```

`--use-param-defaults` tells `tkn` to take the default for `url` instead of asking for it. The output is:

```text
task.tekton.dev/update-deploy created
TaskRun started: update-deploy-run-bkdzf
Waiting for logs to be available...
[commit-tag] fatal: could not read Username for 'http://gitea-http.gitea.svc:3000': No such device or address
```

`git` asked for a user name, because the repository is private, and the step has no terminal to type one into. The TaskRun ran with the service account `default`, which carries no credentials.

## Credentials through a Secret and a service account

Tekton has a built-in way to give Git credentials to every step of a run. You put the credentials in a Secret of type `kubernetes.io/basic-auth`, add an annotation `tekton.dev/git-0` with the address of the Git server, and list the Secret in a ServiceAccount. When a TaskRun uses that ServiceAccount, Tekton writes a `.gitconfig` and a `.git-credentials` file into the home folder of each step, and `git` uses them for that server only.

Save this as `secret-gitea-credentials.yaml`:

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

Run the Task again, this time with the service account (`-s`):

```sh
tkn -n starfleet task start update-deploy -p version=6.14.1 --use-param-defaults -s scout-ci --showlog
tkn -n starfleet taskrun describe --last
```

The output is (the `describe` part is shortened):

```text
TaskRun started: update-deploy-run-7n5sv
Waiting for logs to be available...
[commit-tag] Pushed f49b2f0: Deploy scout 6.14.1

Name:              update-deploy-run-7n5sv
Namespace:         starfleet
Task Ref:          update-deploy
Service Account:   scout-ci
...
Results

 NAME     VALUE
 commit   f49b2f05294bbf9c8a3eed7df935c39bf93e09a6
```

The clone and the push both worked, and the result holds the new commit ID of `scout-deploy`. The service account gives the pipeline access to Git and to nothing else in the cluster. Check that it cannot change the Deployment itself:

```sh
kubectl auth can-i update deployments -n starfleet --as=system:serviceaccount:starfleet:scout-ci
```

The output is:

```text
no
```

## Argo CD delivers the commit

Argo CD checks the repository every few minutes. To see the commit at once, ask for a refresh, wait for the sync, and then send a request from `shuttle`. First log in with the `argocd` tool; the password of the user `admin` is in the Secret `argocd-initial-admin-secret`:

```sh
argocd login 127.0.0.1:8080 --username admin --insecure \
  --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
argocd app get scout --refresh
```

The end of the output is:

```text
Sync Status:        OutOfSync from main (f49b2f0)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME   STATUS     HEALTH   HOOK  MESSAGE
       Service     starfleet  scout  Synced     Healthy        
apps   Deployment  starfleet  scout  OutOfSync  Healthy        
```

The repo server read commit `f49b2f0`, and the Deployment differs from it: the tag in Git is now `6.14.1`. Automated sync applies the change on its own a moment later. Check the result:

```sh
argocd app get scout
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet | grep version
```

The output is (the `argocd` part is shortened to the status lines):

```text
Sync Status:        Synced to main (f49b2f0)
Health Status:      Healthy
...
  "version": "6.14.1",
```

The version `6.14.1` reached `scout` through Git. The pipeline published the image and wrote one line in Git, and the Argo CD application controller did the rest.

You can now commit a tag change from a Task, give a Task Git credentials with a Secret and a service account, and follow the commit to a running version. But you started two Tasks by hand and typed the version twice. The open question is how one run takes the version from the source repository and does all the steps in order.

## Common pitfalls

> [!WARNING]
> - **A Secret without the `tekton.dev/git-0` annotation.** Tekton only turns annotated Secrets into Git credentials. Without it, the Secret is ignored.
> - **An annotation that does not match the clone URL.** The annotation value must be the scheme and host of the repository, here `http://gitea-http.gitea.svc:3000`.
> - **Forgetting the service account on the run.** A TaskRun without `serviceAccountName` (or `-s` in `tkn`) uses `default`, which has no credentials.
> - **Giving the pipeline's service account rights on workloads.** It needs Git access only. Delivery is Argo CD's job.
> - **Committing when nothing changed.** `git commit` fails on an empty change. Check with `git diff --quiet` first, so a repeated run succeeds.
