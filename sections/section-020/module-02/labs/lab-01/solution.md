# Solution

Three objects solve the task: an `AppProject` that limits the `outpost` team, an `ApplicationSet` that generates the two environment applications, and the `Application` of the team. Create the project first, because the team application refers to it.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-020/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: create the AppProject

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

## Step 2: create the ApplicationSet

The `ApplicationSet` controller runs the template once for each element of the list generator. The `Application` name, the Git path and the namespace all take the value of `env`. `missingkey=error` makes a misspelled placeholder fail instead of rendering an empty value.

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

Then check the generated applications:

```sh
kubectl -n argocd get applications
```

The list must show `scout-staging` and `scout-production`. If the `ApplicationSet` has errors, read them with `kubectl -n argocd get applicationset scout-envs -o jsonpath='{.status.conditions}'`.

## Step 3: create the team Application

This `Application` uses the project `outpost`. It has no `CreateNamespace` option, because the project allows no cluster-scoped resource and the namespace `outpost` already exists.

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

## Step 4: check the result

All three applications must reach `Synced` and `Healthy`. This can take up to a minute:

```sh
kubectl -n argocd get applications
```

Then send a request from `shuttle` to each environment:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.outpost/
```

Each JSON response shows a `version`. The first two must show `6.15.0`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

## Common mistakes

- Creating `scout-staging` and `scout-production` by hand. The grader checks that the `ApplicationSet` owns them.
- Forgetting the quotes around `'scout-{{.env}}'`. YAML reads an unquoted value that starts with `{` as a map.
- Adding a wildcard (`*`) to `namespaceResourceWhitelist`. The project must allow only `Deployment` and `Service`.
- Using `project: default` for `outpost-scout`. The `default` project allows every repository and namespace.
- Adding `CreateNamespace=true` to `outpost-scout`. A namespace is a cluster-scoped resource, and the project does not allow it.
