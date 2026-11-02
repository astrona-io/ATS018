# Solution

Four things solve the task. First repair the broken `probe` Application in Git and turn on automated sync. Then create the `AppProject`, the `ApplicationSet` and the team `Application`. Start with `probe`, because it shows the fault that the other objects must not repeat.

## Step 1: find why probe is not healthy

An Argo CD `Application` has two statuses. The sync status says whether the live objects match Git. The health status says whether they work. Read both:

```sh
kubectl -n argocd get application probe
```

The sync status is `Synced`, because Argo CD applied exactly what Git says. The health status is `Degraded` or `Progressing`, because the Deployment never became available. Look at the pod:

```sh
kubectl -n starfleet get pods -l app=probe
kubectl -n starfleet describe pod -l app=probe
```

The pod is in `ErrImagePull` or `ImagePullBackOff`. The event names the image `mccutchen/go-httpbin:2.25.9`, and the registry has no such tag. The correct tag is `2.25.0`. The fault is in Git, so the fix goes in Git. A `kubectl edit` on the Deployment would show `OutOfSync` and a later sync would undo it.

## Step 2: fix the image tag in Git

Clone the repository from the Git server that the lab forwards to your machine, change the tag and push:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-apps.git
cd platform-apps
sed -i.bak 's#go-httpbin:2.25.9#go-httpbin:2.25.0#' apps/probe/deployment.yaml
rm apps/probe/deployment.yaml.bak
git commit -am "Fix the probe image tag"
git push origin main
cd ..
```

The `Application` has no automated sync, so Argo CD shows `OutOfSync` after its next Git poll but does not apply the change.

## Step 3: turn on automated sync

Automated sync makes the application controller apply every new commit. `prune` deletes live objects that are no longer in Git. `selfHeal` reverts manual changes to the live objects.

```sh
kubectl -n argocd patch application probe --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl -n argocd annotate application probe argocd.argoproj.io/refresh=hard --overwrite
```

If the first manual sync is still waiting for the Deployment, it keeps the old commit. Stop it so the new commit is used:

```sh
kubectl -n argocd patch application probe --type merge -p '{"status":{"operationState":{"phase":"Terminating"}}}'
```

Then check the result:

```sh
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/probe --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -s http://probe.starfleet/get
```

## Step 4: create the AppProject

An `AppProject` limits which repositories, destinations and resource kinds its applications may use. Without `clusterResourceWhitelist`, a project allows no cluster-scoped resource. The empty group `''` is the core API group, where `Service` lives.

Save this as `appproject-outpost.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: outpost
  namespace: argocd
spec:
  description: Applications of the outpost team
  sourceRepos:
    - http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git
  destinations:
    - server: https://kubernetes.default.svc
      namespace: outpost
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: ''
      kind: Service
```

Apply it:

```sh
kubectl apply -f appproject-outpost.yaml
```

## Step 5: create the ApplicationSet

The `ApplicationSet` controller runs the template once for each element of the list generator. The `Application` name, the Git path and the namespace all take the value of `env`.

Save this as `applicationset-scout-envs.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: scout-envs
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - list:
        elements:
          - env: staging
          - env: production
  template:
    metadata:
      name: 'scout-{{.env}}'
    spec:
      project: default
      source:
        repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git
        targetRevision: main
        path: 'envs/{{.env}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'starfleet-{{.env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

Apply it:

```sh
kubectl apply -f applicationset-scout-envs.yaml
```

## Step 6: create the team Application

The `Application` `outpost-scout` runs in the project `outpost`, so the project limits from Step 4 apply to it.

Save this as `application-outpost-scout.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: outpost-scout
  namespace: argocd
spec:
  project: outpost
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git
    targetRevision: main
    path: scout
  destination:
    server: https://kubernetes.default.svc
    namespace: outpost
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply it:

```sh
kubectl apply -f application-outpost-scout.yaml
```

Then check the result:

```sh
kubectl -n argocd get applications
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.outpost/
```

All four applications are `Synced` and `Healthy`, and the two `scout` environments answer with version `6.15.0`. Run `astrona submit` to grade the result.
