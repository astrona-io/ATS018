# Solution

Save this as `application-scout-preview.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-preview
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ghcr.io/stefanprodan/charts
    chart: podinfo
    targetRevision: 6.15.0
    helm:
      releaseName: scout
      valuesObject:
        fullnameOverride: scout
        replicaCount: 2
        ui:
          message: preview
  destination:
    server: https://kubernetes.default.svc
    namespace: starfleet-preview
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply it:

```sh
kubectl apply -f application-scout-preview.yaml
```

Wait for reconciliation, then check both ownership and behavior:

```sh
kubectl -n argocd get application scout-preview
kubectl -n starfleet-preview rollout status deploy/scout --timeout=180s
kubectl -n starfleet-preview get deploy scout -o yaml
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-preview:9898/
```

The response must contain version `6.15.0` and message `preview`. Argo CD renders the chart and applies the resulting objects; it does not create Helm release history.
