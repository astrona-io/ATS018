# Solution

Save this as `applicationset-platform-apps.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-apps
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - git:
        repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
        revision: main
        directories:
          - path: apps/*
  template:
    metadata:
      name: '{{.path.basename}}'
      labels:
        team: starfleet
    spec:
      project: default
      source:
        repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
        targetRevision: main
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: starfleet
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

Create it, then add the fourth workload:

```sh
kubectl apply -f applicationset-platform-apps.yaml
kubectl -n argocd get applications -L team
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-apps.git
cd platform-apps
mkdir apps/beacon
sed 's/probe/beacon/g' apps/probe/deployment.yaml > apps/beacon/deployment.yaml
cp apps/probe/kustomization.yaml apps/beacon/
git add apps/beacon
git commit -m "Add beacon"
git push
kubectl -n argocd annotate applicationset platform-apps argocd.argoproj.io/application-set-refresh=true --overwrite
```

After reconciliation, each Application must be Synced and Healthy:

```sh
kubectl -n argocd get applications -L team
kubectl -n argocd get application beacon -o jsonpath='{.metadata.ownerReferences}'
kubectl -n starfleet rollout status deployment/beacon --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://beacon/get
```

The owner reference names `ApplicationSet/platform-apps`. The response contains the HTTP request headers. The new folder is the only per-application configuration you added.
