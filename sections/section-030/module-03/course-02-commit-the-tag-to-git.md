# Commit The Tag To Git

The `ImagePolicy` knows that `6.15.0` is the newest allowed tag, but the Git repository still says `6.14.0`. Flux delivers Git, so the cluster keeps running the old version until a commit changes the file. This part marks the field that holds the tag and creates the object that edits it and pushes the commit.

## Mark the field to update

The `scout` Deployment has no tag of its own. Its image name is `registry.registry.svc:5000/starfleet/scout`, and the Kustomize file `apps/scout/kustomization.yaml` sets the tag with an `images` entry. Kustomize is the tool inside `kubectl` that builds manifests from a folder, and `newTag` replaces the tag of a matching image.

<!-- astrona:playground:renew -->

Clone the repository from Gitea. The playground forwards Gitea to port 3000 on your machine, and the user `platform` has the password `starfleet-gitops`:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-deploy.git
cd scout-deploy
cat apps/scout/kustomization.yaml
```

```text
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: starfleet
resources:
  - deployment.yaml
  - service.yaml
images:
  - name: registry.registry.svc:5000/starfleet/scout
    newTag: 6.14.0
```

A setter marker is a comment at the end of a line that tells the automation which policy value belongs there. The marker `{"$imagepolicy": "flux-system:scout:tag"}` names the namespace, the policy and the part to use: `tag` writes only the tag. Other values are `name`, which writes the image name, and no suffix, which writes name and tag together.

Change the `newTag` line so it reads:

```yaml
    newTag: 6.14.0 # {"$imagepolicy": "flux-system:scout:tag"}
```

Commit and push the change:

```sh
git config user.name platform
git config user.email platform@starfleet.local
git commit -am "Add image policy setter"
git push origin main
```

The commit changes only a comment, so the running `scout` stays on 6.14.0. The marker is a request for the automation. The marker alone does not update anything.

## Create the automation

An `ImageUpdateAutomation` is the object that edits the files. The image automation controller clones the Git repository, replaces every marked value with the tag its policy selected and pushes a commit. The `GitRepository` named in `sourceRef` supplies the URL and the credential Secret. That Secret needs write access, because the same credential is used to push.

Save this as `imageupdateautomation-scout.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageUpdateAutomation
metadata:
  name: scout
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: scout-deploy
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: fluxcdbot
        email: fluxcdbot@starfleet.local
      messageTemplate: "Update {{ range .Changed.Changes }}{{ .OldValue }} to {{ .NewValue }}{{ end }}"
    push:
      branch: main
  update:
    path: ./apps/scout
    strategy: Setters
```

Apply it:

```sh
kubectl apply -f imageupdateautomation-scout.yaml
```

The fields do three jobs. `git.checkout` and `git.push` choose the branch to read and the branch to write. `git.commit` sets the author and a message template. `update.path` limits the search for markers to `./apps/scout`, and `strategy: Setters` means the controller looks for marker comments. Then check the result:

```sh
kubectl -n flux-system wait imageupdateautomation/scout --for=condition=Ready --timeout=90s
flux get image update -n flux-system
```

```text
NAME 	LAST RUN                 	SUSPENDED	READY	MESSAGE               
scout	2026-11-01T22:12:43+01:00	False    	True 	repository up-to-date
```

`repository up-to-date` is the message after a run. It means the files now match the policy, and it does not tell you whether this run pushed anything. The status holds that answer.

## Follow the commit to the pods

Read the commit the automation pushed:

```sh
kubectl -n flux-system get imageupdateautomation scout -o jsonpath='{.status.lastPushCommit}{"\n"}'
git pull
git log --format='%h %an %s'
git show HEAD -- apps/scout/kustomization.yaml
```

The commit hashes differ on your machine. The log output was:

```text
57e8e63 fluxcdbot Update 6.14.0 to 6.15.0
4240f2e platform Add image policy setter
87fae37 platform Initial content of scout-deploy
```

The top commit is from `fluxcdbot`, the author set in the automation, and its message came from the template. `git show` prints the diff. The lines below are shortened to the changed line:

```text
-    newTag: 6.14.0 # {"$imagepolicy": "flux-system:scout:tag"}
+    newTag: 6.15.0 # {"$imagepolicy": "flux-system:scout:tag"}
```

The marker stays in place, so the next run can update the same line again. Now ask the source controller to fetch the new commit, and wait for the `Kustomization` that applies it. The `GitRepository` checks Git every minute, so the command only saves waiting:

```sh
flux reconcile source git scout-deploy -n flux-system
flux get kustomizations -n flux-system
kubectl -n starfleet rollout status deploy/scout --timeout=90s
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet.svc
```

The kustomize controller applied the new commit, and the Deployment rolled out. The status line and the response, shortened to the version lines, were:

```text
NAME 	REVISION          	SUSPENDED	READY	MESSAGE                              
scout	main@sha1:57e8e63a	False    	True 	Applied revision: main@sha1:57e8e63a
```

```text
  "version": "6.15.0",
  "message": "greetings from podinfo v6.15.0",
```

Every component did one job. The image reflector controller picked the tag. The image automation controller wrote the commit. The source controller fetched it, and the kustomize controller applied it. The change is in Git history, so you can review it or revert it like a change by a person.

You now have the full path from a policy to a running pod. What you have not seen is the path starting from the registry: a new tag published after setup, and the status of each object while it moves through.

## Common pitfalls

> [!WARNING]
> - **Writing the marker with the wrong policy name.** The marker must name `flux-system:scout:tag`, the namespace and name of the policy. A wrong name leaves the line unchanged.
> - **Putting the marker on a line outside `update.path`.** The controller searches only that path.
> - **Using a read-only credential in the `GitRepository` Secret.** The controller can clone but the push fails.
> - **Reading `repository up-to-date` as proof of a push.** Check `lastPushCommit` or `git log`.
