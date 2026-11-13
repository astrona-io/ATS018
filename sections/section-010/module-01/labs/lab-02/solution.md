# Solution Walkthrough

Complete the staging overlay of `scout` and apply it with the Kustomize built into `kubectl`. A Kustomize base is a folder of shared manifests. An overlay is a folder that includes the base and changes it for one environment.

| Goal | Where it lives | Command or file |
| --- | --- | --- |
| Shared manifests | Base, unchanged | `scout/base` |
| Staging settings | Overlay | `scout/overlays/staging/kustomization.yaml` |
| Environment reference | Patch | `scout/overlays/staging/deployment-env.yaml` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-01/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

The `overlay` check needs work at startup. This is an expected condition, not a captured grading transcript.

## Step 1: Inspect the starting files

Use the lab terminal:

```sh
cd ~/resources
cat scout/base/kustomization.yaml
kubectl kustomize scout/overlays/staging
```

The base lists a Deployment and a Service with image `6.14.0`. The overlay only includes its base. It does not yet set the namespace, the image tag, the replica count or the generated configuration, so the check is not ready yet.

## Step 2: Complete the staging overlay

Save this as `~/resources/scout/overlays/staging/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: starfleet-staging
resources:
  - ../../base
images:
  - name: ghcr.io/stefanprodan/podinfo
    newTag: 6.15.0
replicas:
  - name: scout
    count: 1
configMapGenerator:
  - name: scout-settings
    literals:
      - PODINFO_UI_MESSAGE=overlay-staging
patches:
  - path: deployment-env.yaml
```

`resources` includes the unchanged base, and `namespace` sets the destination. `images` changes the application tag. `replicas` sets one pod. `configMapGenerator` creates the settings object with a content hash in its name. `patches` adds the environment reference to the Deployment.

Save this as `~/resources/scout/overlays/staging/deployment-env.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
spec:
  template:
    spec:
      containers:
        - name: scout
          envFrom:
            - configMapRef:
                name: scout-settings
```

The patch selects Deployment `scout` and merges the container named `scout`. Its `envFrom` loads the generated ConfigMap. Kustomize replaces `scout-settings` with the generated name in the rendered Deployment.

Render before applying:

```sh
kubectl kustomize scout/overlays/staging
```

Look for namespace `starfleet-staging`, image `6.15.0`, one replica and a generated ConfigMap name that matches the Deployment reference.

Apply it:

```sh
kubectl apply -k scout/overlays/staging
```

Then check the result:

```sh
kubectl -n starfleet-staging rollout status deploy/scout --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-staging/
```

The response must show version `6.15.0` and the message `overlay-staging`. Also compare the overlay with the cluster:

```sh
kubectl diff -k scout/overlays/staging
```

No output means the live objects match the files.

The watch terminal shows the `overlay` check passing. Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-01/labs/lab-02
```

## If a check stays red

- **Base changed:** The grader compares `base` with the starting files. Undo any edit there and make the change in the overlay.
- **Namespace or patch:** Check the `namespace` field and the container name in the patch. A patch for a container that does not exist adds a second container.
- **ConfigMap name:** Keep the generator hash enabled and reference `scout-settings` through `envFrom`. Kustomize writes the generated name into the Deployment.
- **Diff not clean:** Apply the saved overlay again if its files differ from the cluster.
