# AppProjects For A Second Tenant

Every application so far belongs to the project `default`, and `default` allows everything: any repository, any cluster, any namespace, any kind of object. On a platform shared by several teams that is a problem. A typo in one team's `destination.namespace` deploys into another team's namespace, and nothing stops it. This part gives the `outpost` team its own `AppProject` and tests each of its limits.

## What the default project allows

An `AppProject` is an Argo CD custom resource that limits what the applications in it may do. Every `Application` names exactly one project in `spec.project`. Look at the rules of `default`:

<!-- astrona:playground:renew -->

```sh
kubectl -n argocd get appproject default -o jsonpath='{.spec}'
```

You should see:

```text
{"clusterResourceWhitelist":[{"group":"*","kind":"*"}],"destinations":[{"namespace":"*","server":"*"}],"sourceRepos":["*"]}
```

Every rule is `*`. The three fields are the ones you will set for a tenant:

- `sourceRepos` lists the repositories its applications may render.
- `destinations` lists the clusters and namespaces they may deploy to.
- `clusterResourceWhitelist` and `namespaceResourceWhitelist` list the kinds of objects they may create, cluster-wide (such as Namespaces) and inside namespaces. A kind that is not listed is refused.

## A project for outpost

The `outpost` team should render only its own repository, deploy only into the namespace `outpost`, and create only Deployments and Services.

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

The project has no `clusterResourceWhitelist`, so its applications may not create any cluster-wide object, not even their own namespace. The empty group `''` is the core API group, where Services, ConfigMaps and Secrets live. Apply it:

```sh
kubectl apply -f appproject-outpost.yaml
```

## Each rule, broken once

Write the team's first application with a mistake in it: the destination namespace is `starfleet`.

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
    namespace: starfleet
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply it, then read its status:

```sh
kubectl apply -f application-outpost-scout.yaml
argocd app get outpost-scout
```

The end of the output is:

```text
Sync Status:        Unknown
Health Status:      Unknown

CONDITION         MESSAGE                                                                                                                                                      LAST TRANSITION
InvalidSpecError  application destination server 'https://kubernetes.default.svc' and namespace 'starfleet' do not match any of the allowed destinations in project 'outpost'  2026-10-10 17:49:19 +0200 CEST
```

The API server accepted the `Application`, but Argo CD refuses to work on it. The condition `InvalidSpecError` names the rule and the project. Nothing was rendered or deployed. A repository outside `sourceRepos` gives the same condition with a different message; if you point the source at `platform-apps.git`, it reads `application repo http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git is not permitted in project 'outpost'`.

Fix the destination. In `application-outpost-scout.yaml`, change `namespace: starfleet` under `destination` to `namespace: outpost`, apply it, and check again:

```sh
kubectl apply -f application-outpost-scout.yaml
argocd app get outpost-scout
```

The end of the output is:

```text
Sync Status:        Synced to main (596f161)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME   STATUS  HEALTH   HOOK  MESSAGE
       Service     outpost    scout  Synced  Healthy        service/scout created
apps   Deployment  outpost    scout  Synced  Healthy        deployment.apps/scout created
```

The last rule is about kinds. Add a ConfigMap to the team's repository. Clone it first:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/outpost-apps.git
cd outpost-apps
```

Save this as `scout/notes.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scout-notes
data:
  owner: outpost-team
```

Add `- notes.yaml` under `resources` in `scout/kustomization.yaml`, then commit, push and refresh:

```sh
git add -A
git commit -m "Add notes"
git push
argocd app get outpost-scout --refresh
```

After a few seconds, `argocd app get outpost-scout` shows:

```text
Sync Status:        OutOfSync from main (6800c8e)
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME         STATUS   HEALTH   HOOK  MESSAGE
       ConfigMap   outpost    scout-notes  Unknown  Missing        resource :ConfigMap is not permitted in project outpost
       Service     outpost    scout        Synced   Healthy        
apps   Deployment  outpost    scout        Synced   Healthy
```

This time the application itself is valid, so Argo CD renders it and syncs what it may. The one object it may not create stays `Missing`, with a message on that object. `resource :ConfigMap` is `<group>:<kind>` with an empty group. The application stays `OutOfSync` until the project allows ConfigMaps or the file leaves Git.

```mermaid
flowchart TB
    A["Application, project outpost"] -->|"repo in sourceRepos?"| R{"repo allowed"}
    R -->|"no"| E1["InvalidSpecError"]
    R -->|"yes"| D{"destination allowed"}
    D -->|"no"| E2["InvalidSpecError"]
    D -->|"yes"| K{"kind whitelisted"}
    K -->|"no"| E3["object not permitted"]
    K -->|"yes"| S["synced"]
```

The diagram shows the order of the checks: repository and destination make the whole application invalid, while a kind that is not allowed only blocks that one object.

An `AppProject` is also where Argo CD role-based access for people is scoped: its `roles` field gives a team permission to sync only its own applications. With projects in place, an `ApplicationSet` for a tenant sets `project: outpost` in its template, and every generated application inherits the limits.

You can now give a team its own project, restrict its repositories, namespaces and kinds, and tell from the status which rule an application broke. Together with app of apps and `ApplicationSet` generators, that is what you need to run many applications for more than one team.

## Common pitfalls

> [!WARNING]
> - **Leaving tenant applications in `default`.** That project allows every repository, namespace and kind.
> - **Forgetting the core group is empty.** Services and ConfigMaps use `group: ''`, not `group: v1` or `core`.
> - **Putting a Namespace manifest in a tenant's repository.** A Namespace is a cluster-wide object, and a project without a `clusterResourceWhitelist` refuses it. The platform team creates tenant namespaces.
> - **Reading an `InvalidSpecError` as a Git problem.** It means the `Application` breaks a project rule; nothing was fetched or rendered.
