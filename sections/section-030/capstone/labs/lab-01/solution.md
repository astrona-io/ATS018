# Solution

Two deliveries are broken. Steps 1 to 5 repair the delivery from Git: the source, the two Kustomizations and a change pushed to Git. Steps 6 to 8 repair the Helm release. The two parts do not depend on each other.

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

## Step 5: prove the Git delivery

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
```

The response shows `"message": "staging-v2"`.

## Step 6: read why the release is not Ready

```sh
flux get helmreleases -n starfleet
kubectl -n starfleet get helmrelease relay -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl -n starfleet get helmrelease relay -o jsonpath='{range .status.history[*]}{.version}{" "}{.status}{"\n"}{end}'
```

The `Ready` condition has the reason `UpgradeFailed`. The history lists a `failed` revision and the earlier `deployed` one. Read the values the release asks for:

```sh
kubectl -n starfleet get helmrelease relay -o jsonpath='{.spec.values}'
```

The values contain `faults.unready: true`. That chart value makes the podinfo readiness check fail, so the Deployment never becomes ready and Helm marks the upgrade as failed.

## Step 7: repair the values and add remediation

Save this as `helmrelease-relay.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: relay
  namespace: starfleet
spec:
  interval: 1m
  timeout: 30s
  chartRef:
    kind: OCIRepository
    name: podinfo
  values:
    replicaCount: 1
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        memory: 128Mi
    faults:
      unready: false
  upgrade:
    remediation:
      retries: 1
      remediateLastFailure: true
      strategy: rollback
```

Apply it:

```sh
kubectl apply -f helmrelease-relay.yaml
```

Then check the result:

```sh
flux reconcile helmrelease relay -n starfleet --reset
flux get helmreleases -n starfleet
```

`--reset` clears the failure counters and asks the helm controller to reconcile now. The release becomes `Ready` with a new `deployed` revision.

## Step 8: prove the application answers

```sh
kubectl -n starfleet get deploy relay-podinfo
kubectl -n starfleet exec deploy/shuttle -- curl -s http://relay-podinfo.starfleet:9898/
```

The Deployment has 1 ready replica and the response shows `"version": "6.15.0"`. Run `astrona submit` to grade.
