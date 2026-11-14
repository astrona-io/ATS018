# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-040/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: read the status of the source and the Kustomization

```sh
flux get sources git -n flux-system
flux get kustomizations -n flux-system
```

The `GitRepository` `scout` is not `Ready`, and the `Kustomization` `scout` waits for a source artifact. The other objects in the list come back in a later step. Read the reason:

```sh
kubectl -n flux-system describe gitrepository scout
```

The source controller reports that it cannot find the reference for the branch `master`. The repository has the branch `main`.

## Step 2: fix the branch of the source

Save this as `gitrepository-scout.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: scout
  namespace: flux-system
spec:
  interval: 1m
  url: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
  ref:
    branch: main
  secretRef:
    name: scout-readonly
```

Apply it:

```sh
kubectl apply -f gitrepository-scout.yaml
```

Then check the result:

```sh
flux get sources git -n flux-system
```

The source is `Ready` and shows the revision `main@sha1:<commit>`.

## Step 3: add the platform Kustomization and the dependency

The `scout` `Kustomization` deploys into `starfleet-staging`, but only the `platform` path creates that namespace. Save this as `kustomization-platform.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 1m
  path: ./platform
  prune: true
  sourceRef:
    kind: GitRepository
    name: scout
```

Save this as `kustomization-scout.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: scout
  namespace: flux-system
spec:
  interval: 1m
  path: ./overlays/staging
  prune: true
  targetNamespace: starfleet-staging
  wait: true
  timeout: 1m
  dependsOn:
    - name: platform
  sourceRef:
    kind: GitRepository
    name: scout
```

Apply both:

```sh
kubectl apply -f kustomization-platform.yaml -f kustomization-scout.yaml
```

Then check the result:

```sh
flux get kustomizations -n flux-system
```

The `platform` and `scout` objects become `Ready`. The `kustomize-controller` applies `platform` first and applies `scout` only after `platform` is `Ready`.

## Step 4: change the message in Git

Clone the repository, change the value and push:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-deploy.git
cd scout-deploy
sed -i 's/value: staging$/value: staging-v2/' overlays/staging/message.yaml
git add overlays/staging/message.yaml
git commit -m "Update staging message"
git push origin main
```

On macOS, use `sed -i ''` instead of `sed -i`, or edit the file with an editor.

Ask Flux to fetch the commit now instead of waiting for the interval:

```sh
flux reconcile kustomization scout -n flux-system --with-source
```

## Step 5: prove the staging result

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
```

The response shows `"message": "staging-v2"`.

## Step 6: find the suspended Kustomization

A suspended `Kustomization` is a Flux object that the `kustomize-controller` no longer reconciles. It keeps the objects it applied, but it stops applying changes and correcting drift. Drift is a difference between the live cluster and Git. List every `Kustomization`:

```sh
flux get kustomizations -n flux-system
```

Read the `SUSPENDED` column. The row for `scout-production` says `True`. Its `READY` column can still say `True`, because that value records the last completed reconciliation. It does not prove the live objects match Git.

Compare the live workload with Git. The Git value is in `overlays/production/message.yaml` in your clone, and the live value comes from the running pods:

```sh
cat overlays/production/message.yaml
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/
```

Git says `production`. The `message` field in the response has a different value, so the live Deployment has drifted.

## Step 7: resume it and prove the drift is gone

Do not change Git to match the drift, because Git holds the desired state. Clear the suspension instead, so the controller reconciles again:

```sh
flux resume kustomization scout-production -n flux-system
```

The `flux resume` command clears `spec.suspend` and waits for the reconciliation to finish. The `kustomize-controller` applies the desired state from Git over the changed value. That starts a rollout of new pods, so wait for it and send the request again:

```sh
kubectl -n starfleet-production rollout status deployment/scout
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/
flux get kustomizations -n flux-system
```

The response shows `"message": "production"`. All three `Kustomization` objects show `False` under `SUSPENDED` and `True` under `READY`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```
