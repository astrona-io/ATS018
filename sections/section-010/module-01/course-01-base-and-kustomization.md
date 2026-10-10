# One Base, Rendered Before It Is Applied

A GitOps controller is a program in the cluster that reads manifests from a Git repository and changes the cluster until it matches them. It does this every few minutes, without a person in the loop. So the files in Git must render to the same manifests every time, and they must render for each environment that the controller manages. This part builds the first half of that setup: the base, the files every environment shares. You render it on your own machine before anything reaches the cluster.

## Why the rendered output matters

You could keep one complete copy of the manifests per environment. That works for a week. Then someone changes the container port in the staging copy and forgets the production copy, and the two environments drift apart without anyone noticing. The copies hide which differences are on purpose and which are mistakes.

Kustomize turns this around. You keep **one** set of plain manifests, called the **base**. Each environment gets an **overlay**: a folder whose `kustomization.yaml` points at the base and lists only the changes for that environment. Kustomize reads the base, applies the overlay's changes to a copy, and prints the finished manifests. Nothing in the base changes on disk.

The finished manifests are called the **rendered output**. This is what a GitOps controller applies, and it is what you should read before you apply anything yourself. Kustomize is deterministic: the same files always produce the same rendered output, byte for byte. That property is what lets a controller compare Git with the cluster and decide that nothing needs to change.

## The base

The base for `scout` holds a Deployment and a Service. Start with a new, empty folder called `scout` on your machine, with a `base` folder inside it. Every path in this module is relative to the `scout` folder, so run every command from there.

<!-- astrona:playground:renew -->

Save this as `base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
```

The image has no tag on purpose. The `kustomization.yaml` sets the tag, so it lives in one place that an overlay can change. The readiness probe asks `podinfo` on `/readyz` whether it can take traffic, so the Service only sends requests to a pod that is ready.

Save this as `base/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: scout
spec:
  selector:
    app: scout
  ports:
    - name: http
      port: 80
      targetPort: http
```

These two files are ordinary Kubernetes manifests. You could apply each of them with `kubectl apply -f`. Kustomize needs one more file that says which manifests belong together and what to change in them.

## The kustomization.yaml file

A `kustomization.yaml` file is the instruction file that Kustomize reads in a folder. A folder that has one is called a **kustomization**. Kustomize only reads the files that this file names.

Save this as `base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
labels:
  - pairs:
      app.kubernetes.io/part-of: starfleet
images:
  - name: ghcr.io/stefanprodan/podinfo
    newTag: 6.14.0
```

Three fields do the work here:

- `resources` lists the manifests to include. An entry can be a file or another folder that has its own `kustomization.yaml`. The order of the list does not decide the order of the output.
- `labels` adds labels to every object. With only `pairs`, Kustomize adds them to each object's `metadata.labels` and leaves selectors alone.
- `images` changes the image of every container whose image name matches `name`. `newTag` sets the tag. The field can also set `newName` to swap the registry or repository, or `digest` to pin an exact image.

The `apiVersion` and `kind` lines are optional, and many examples leave them out. Keep them: they tell a reader, and an editor with a schema, what kind of file this is.

## Render the base

`kubectl kustomize` runs Kustomize on a folder and prints the rendered output. It does not contact the cluster, so it is safe to run as often as you like.

```sh
kubectl kustomize base
```

You should see:

```text
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/part-of: starfleet
  name: scout
spec:
  ports:
  - name: http
    port: 80
    targetPort: http
  selector:
    app: scout
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/part-of: starfleet
  name: scout
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      containers:
      - image: ghcr.io/stefanprodan/podinfo:6.14.0
        name: scout
        ports:
        - containerPort: 9898
          name: http
        readinessProbe:
          httpGet:
            path: /readyz
            port: http
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
```

Compare the output with your files. The image now carries the tag `6.14.0`, which came from the `images` field. Both objects carry the `app.kubernetes.io/part-of: starfleet` label, but the Deployment's `selector` and pod template labels are unchanged. Kustomize also sorted the output: the Service comes before the Deployment, because Kustomize prints objects that others depend on, such as namespaces and Services, before workloads.

## Why selectors stay untouched

Older Kustomize files use a field called `commonLabels`. It still works, but it adds the label everywhere, including to `spec.selector` and to the pod template. Below is the start of the rendered Deployment when `commonLabels` with `team: platform` is added to the base (shortened to the part that matters):

```text
# Warning: 'commonLabels' is deprecated. Please use 'labels' instead. Run 'kustomize edit fix' to update your Kustomization automatically.
...
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/part-of: starfleet
    team: platform
  name: scout
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scout
      team: platform
```

The selector now contains `team: platform`. A Deployment's selector cannot be changed after the Deployment is created, so the next apply to a running Deployment fails, and a GitOps controller then reports the application as failed. The `labels` field with only `pairs` avoids this. If you really want a label in the selectors of a brand new application, `labels` also accepts `includeSelectors: true`.

You now have a base that renders to two complete manifests without touching the cluster, with the image tag and a shared label set in one file. The base still describes only one environment, though. The next question is how staging and production can each change it without copying it.

## Common pitfalls

> [!WARNING]
> - **Running the commands from the wrong folder.** Every path in a `kustomization.yaml` is relative to the folder that holds that file, and every command in this module runs from the `scout` folder.
> - **Putting the image tag in both places.** If `deployment.yaml` has a tag and `images` sets `newTag`, `newTag` wins, and the tag in the file only misleads the next reader.
> - **Using `commonLabels` on a running application.** It changes the selector, and a Deployment's selector cannot change. Use `labels` with `pairs`.
> - **Expecting a file in the folder to be included on its own.** Kustomize reads only what `resources` lists.
