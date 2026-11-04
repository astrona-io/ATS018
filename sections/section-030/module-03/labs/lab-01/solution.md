# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/module-03/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: scan the registry

Save this as `imagerepository-scout.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: scout
  namespace: flux-system
spec:
  image: registry.registry.svc:5000/starfleet/scout
  interval: 1m
  insecure: true
```

Apply it:

```sh
kubectl apply -f imagerepository-scout.yaml
```

Then check the result:

```sh
flux get image repository -n flux-system
```

The registry has no TLS, so `insecure: true` is required. Without it the scan fails with a connection error. The repository is `Ready` and reports the tags it found.

## Step 2: choose the tag with a policy

Save this as `imagepolicy-scout.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: scout
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: scout
  policy:
    semver:
      range: ">=6.14.0"
```

Apply it:

```sh
kubectl apply -f imagepolicy-scout.yaml
```

Then check the result:

```sh
flux get image policy -n flux-system
```

The `TAG` column shows `6.15.0`.

## Step 3: add the setter marker in Git

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-deploy.git
cd scout-deploy
```

In `apps/scout/kustomization.yaml`, change the `newTag` line to:

```yaml
    newTag: 6.14.0 # {"$imagepolicy": "flux-system:scout:tag"}
```

Commit and push:

```sh
git config user.name platform
git config user.email platform@starfleet.local
git commit -am "Add image policy setter"
git push origin main
```

## Step 4: create the automation

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

Then check the result:

```sh
kubectl -n flux-system get imageupdateautomation scout -o jsonpath='{.status.lastPushCommit}{"\n"}'
```

The command prints the commit hash after the first run. The message `repository up-to-date` in `flux get image update` does not show whether a push happened, so read `lastPushCommit`.

## Step 5: prove the delivery

```sh
flux reconcile source git scout-deploy -n flux-system
kubectl -n starfleet rollout status deploy/scout --timeout=90s
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet.svc/
```

The response shows `"version": "6.15.0"`. In your clone, `git pull` and `git log` show the commit from `fluxcdbot`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-030/module-03/labs/lab-01
```
