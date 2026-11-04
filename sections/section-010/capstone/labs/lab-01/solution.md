# Solution

Work from the `scout` folder. Copy it out of the resources first if you have not yet:

```sh
astrona res copy scout
cd scout
```

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-010/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: build staging and read the first error

```sh
kubectl kustomize overlays/staging
```

The command stops at the first fault (the long paths in the real message are shortened here):

```text
error: accumulating resources: accumulation err='accumulating resources from '../../base': '.../base' must resolve to a file': recursed accumulation of path '.../base': accumulating resources: accumulation err='accumulating resources from 'service.yml': evalsymlink failure on '.../base/service.yml' : lstat .../base/service.yml: no such file or directory'
```

`accumulating resources from 'service.yml'` names the broken entry. The file in the base is `service.yaml`. In `base/kustomization.yaml`, change `service.yml` to `service.yaml`.

## Step 2: find the staging fault that has no error

Build staging again and look at the image:

```sh
kubectl kustomize overlays/staging | grep image:
```

```text
        image: ghcr.io/stefanprodan/podinfo:6.14.0
```

The build works, but the image tag is `6.14.0` from the base, not `6.15.0`. The `images` entry in `overlays/staging/kustomization.yaml` uses `name: podinfo`. Kustomize matches the `name` field against the full image name in the Deployment, which is `ghcr.io/stefanprodan/podinfo`. A short name matches nothing, and Kustomize does not report that. Change the entry to `name: ghcr.io/stefanprodan/podinfo` and build again: the image is now `6.15.0`.

## Step 3: build production and read the second error

```sh
kubectl kustomize overlays/production
```

```text
error: resource with name scouts does not match a config with the following GVK [Deployment.[noVer].[noGrp] StatefulSet.[noVer].[noGrp] ReplicaSet.[noVer].[noGrp] ReplicationController.[noVer].[noGrp]]
```

The `replicas` entry names a Deployment `scouts`. The Deployment is `scout`. In `overlays/production/kustomization.yaml`, change `name: scouts` to `name: scout`.

## Step 4: find the production fault that has no error

Build production again and compare the ConfigMap name with the name the Deployment uses:

```sh
kubectl kustomize overlays/production | grep -E "kind: ConfigMap|scout-config|scout-settings"
```

```text
kind: ConfigMap
  name: scout-config-bfgtt8m25c
            name: scout-settings
```

The generator creates `scout-config-<hash>`, but the patch in `overlays/production/deployment-env.yaml` refers to `scout-settings`. Kustomize rewrites a reference only when the name matches a generated ConfigMap. Here it matches none, so the Deployment keeps the plain name `scout-settings`, and that ConfigMap does not exist. The pods would stop in `CreateContainerConfigError`. In `overlays/production/kustomization.yaml`, change the generator `name: scout-config` to `name: scout-settings`. Build again: the Deployment now names `scout-settings-<hash>`.

## Step 5: apply both overlays

```sh
kubectl apply -k overlays/staging
kubectl apply -k overlays/production
```

## Step 6: prove it from shuttle

```sh
kubectl -n starfleet-staging rollout status deploy/scout
kubectl -n starfleet-production rollout status deploy/scout
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/
```

The staging response has `"version": "6.15.0"` and `"message": "staging"`. The production response has `"version": "6.14.0"` and `"message": "production"`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```
