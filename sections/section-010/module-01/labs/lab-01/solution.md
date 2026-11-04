# Solution

Work from the `scout` folder. Copy it out of the resources first if you have not yet:

```sh
astrona res copy scout
cd scout
```

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-010/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: build staging and read the error

```sh
kubectl kustomize overlays/staging
```

The command stops at the first fault (the long path in the real message is shortened here):

```text
error: accumulating resources: accumulation err='accumulating resources from '../base': evalsymlink failure on '.../overlays/base' : lstat .../overlays/base: no such file or directory'
```

`accumulating resources` means a `resources` entry is wrong. The path `../base` from `overlays/staging` points to `overlays/base`. The base is two levels up. In `overlays/staging/kustomization.yaml`, change the entry to `../../base`.

## Step 2: fix the patch name in staging

Build again:

```sh
kubectl kustomize overlays/staging
```

The build now stops at the patch file because its `metadata.name` is `scouts`, but the Deployment in the base is `scout`. The patch matches no object. In `overlays/staging/deployment-env.yaml`, change `name: scouts` to `name: scout`. Build once more and check that the Deployment has the image tag `6.15.0` and an `envFrom` block that names `scout-settings-<hash>`.

## Step 3: find the silent fault in production

```sh
kubectl kustomize overlays/production
```

This build succeeds. Read the Deployment: the container has `memory: 32Mi` as its request and no `limits` block, so the JSON 6902 patch did nothing. The patch `target` contains `namespace: starfleet-production`. Patches run before the `namespace` field is applied, so no object has that namespace yet and the target selects nothing. Remove the `namespace` line from the `target` block in `overlays/production/kustomization.yaml`. Build again: the request is `64Mi` and the limit is `128Mi`.

## Step 4: apply both overlays

```sh
kubectl apply -k overlays/staging
kubectl apply -k overlays/production
```

## Step 5: prove it from shuttle

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/
```

The staging response has `"version": "6.15.0"` and `"message": "staging"`. The production response has `"version": "6.14.0"`. If a request fails right after the apply, wait for `kubectl -n starfleet-staging rollout status deploy/scout` to finish and send it again.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```
