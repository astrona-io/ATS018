# Solution

Save this as `application-platform-apps.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
    targetRevision: main
    path: argocd-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply it:

```sh
kubectl apply -f application-platform-apps.yaml
```

Wait for the child Applications to appear, then inspect each one:

```sh
kubectl -n argocd get applications
kubectl -n argocd get application scout probe bridge -o yaml
kubectl -n starfleet get deployments
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout/
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://probe/get
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://bridge/
```

Each child must be Synced and Healthy. Its tracking annotation identifies `platform-apps` as the parent that delivered it.
