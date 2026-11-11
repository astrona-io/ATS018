# Solution

Save this as `flux-platform.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform-infra
  namespace: flux-system
spec:
  interval: 1m
  url: http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git
  ref:
    branch: main
  secretRef:
    name: platform-infra-auth

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: platform-infra
  path: ./platform
  prune: true
  wait: true
  timeout: 2m

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: environments
  namespace: flux-system
spec:
  interval: 1m
  dependsOn:
    - name: platform
  sourceRef:
    kind: GitRepository
    name: platform-infra
  path: ./environments
  prune: true
  wait: true
  timeout: 2m
```

Apply it:

```sh
kubectl apply -f flux-platform.yaml
```

Inspect the source, the Kustomizations and production health. The platform must become Ready before the environments are applied:

```sh
kubectl -n flux-system get gitrepositories,kustomizations
kubectl -n starfleet-production get scoutenvironments.platform.starfleet.dev scout -o yaml
kubectl -n starfleet-production get pods
```

Clone the repository and change `spec.version` in `environments/production/scoutenvironment.yaml` to `6.15.0`:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-infra.git platform-infra-fix
cd platform-infra-fix
```

Save the file, then commit and push:

```sh
git add environments/production/scoutenvironment.yaml
git -c user.name=platform -c user.email=platform@starfleet.local commit -m "Use the published production version"
git push origin main
```

Allow the one-minute source and reconciliation intervals to elapse. Check the applied revisions and wait for both environments:

```sh
kubectl -n flux-system get gitrepositories,kustomizations
kubectl get scoutenvironments.platform.starfleet.dev -A
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-staging/
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

The production image error disappears after Flux applies the commit and Crossplane updates the Deployment. The messages remain `staging` and `production`.
