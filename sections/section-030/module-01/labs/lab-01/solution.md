# Solution

## Step 1: read the status of the source and the Kustomization

```sh
flux get sources git -n flux-system
flux get kustomizations -n flux-system
```

The `GitRepository` `scout` is not `Ready`, and the `Kustomization` `scout` waits for a source artifact. Read the reason:

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

Both objects become `Ready`. The `kustomize-controller` applies `platform` first and applies `scout` only after `platform` is `Ready`.

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

## Step 5: prove the result

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
```

The response shows `"message": "staging-v2"`. Run `astrona submit` to grade.
