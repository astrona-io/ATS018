# ApplicationSets And Generators

The app of apps pattern still needs one hand-written manifest per application. An `ApplicationSet` replaces those copies with one template and a generator that produces the values to fill it. The ApplicationSet controller, the `argocd-applicationset-controller` pod, creates, updates and deletes the `Application` objects for you. This part generates `scout` once per environment from a list, and then one application per folder from the Git repository.

## Generators and the template

An `ApplicationSet` has two halves. A **generator** produces a list of parameter sets, for example `{env: staging}` and `{env: production}`. The **template** is an `Application` spec with placeholders, filled once per parameter set. Each result becomes one `Application`.

```mermaid
flowchart TB
    G["list generator"] -->|"env: staging"| T["template"]
    G -->|"env: production"| T
    T -->|"fill"| A1["Application scout-staging"]
    T -->|"fill"| A2["Application scout-production"]
    A1 -->|"sync"| N1["starfleet-staging"]
    A2 -->|"sync"| N2["starfleet-production"]
```

The diagram shows one generator producing two parameter sets, the template turning each into an `Application`, and each `Application` syncing its own namespace.

With `goTemplate: true`, placeholders use Go template syntax: `{{.env}}` is the parameter `env`. The option `missingkey=error` makes a typo in a parameter name an error instead of an empty string. Without it, `{{.evn}}` would quietly render as nothing and produce an `Application` called `scout-`.

## One Application per environment

The `platform-apps` repository has `envs/staging` and `envs/production`, two Kustomize folders that deliver `scout` with one and two replicas. A list generator names the environments directly in the `ApplicationSet`.

<!-- astrona:playground:renew -->

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

The placeholders are quoted, because a YAML value that starts with `{` would otherwise be read as a map. Apply it:

```sh
kubectl apply -f applicationset-scout-envs.yaml
```

Then check the result after a few seconds:

```sh
kubectl -n argocd get applications
kubectl -n argocd get applicationset scout-envs \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

You should see:

```text
NAME               SYNC STATUS   HEALTH STATUS
bridge             Synced        Healthy
probe              Synced        Healthy
scout              Synced        Healthy
scout-production   Synced        Healthy
scout-staging      Synced        Healthy
ErrorOccurred=False ApplicationSetUpToDate: All applications have been generated successfully
ParametersGenerated=True ParametersGenerated: Successfully generated parameters for all Applications
ResourcesUpToDate=True ApplicationSetUpToDate: All applications have been generated successfully
```

Two new applications, `scout-production` and `scout-staging`, each synced into its own namespace. The conditions of the `ApplicationSet` are where its own errors appear: a template that does not render, or a generator that cannot read Git, shows up as `ErrorOccurred=True` with a message.

Each generated `Application` names its owner:

```sh
kubectl -n argocd get application scout-production \
  -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}'
```

You should see:

```text
ApplicationSet/scout-envs
```

The owner reference means the `ApplicationSet` is in charge. If you edit a generated `Application` by hand, the controller sets it back to what the template says. A third environment is now one more line under `elements`.

## One Application per folder

The list still names every value. A **Git directory generator** reads the repository instead: it produces one parameter set for each folder that matches a pattern. The parameters it provides include `{{.path.path}}` (the full folder path, for example `apps/scout`) and `{{.path.basename}}` (the last part, `scout`).

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

Apply it, and list the applications with their `team` label:

```sh
kubectl apply -f applicationset-platform-apps.yaml
kubectl -n argocd get applications -L team
```

You should see:

```text
NAME               SYNC STATUS   HEALTH STATUS   TEAM
bridge             Synced        Healthy         starfleet
probe              Synced        Healthy         starfleet
scout              Synced        Healthy         starfleet
scout-production   Synced        Healthy         
scout-staging      Synced        Healthy         
```

The three applications left behind by the deleted parent now carry the label `team: starfleet` from the template. The generator produced the same names, `bridge`, `probe` and `scout`, so the `ApplicationSet` took over the existing objects instead of creating new ones. Their workloads kept running the whole time.

Now add a service the GitOps way, with a folder. Clone the repository, copy `apps/probe` to `apps/beacon` with every `probe` renamed to `beacon`, and push:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-apps.git
cd platform-apps
mkdir apps/beacon
sed 's/probe/beacon/g' apps/probe/deployment.yaml > apps/beacon/deployment.yaml
cp apps/probe/kustomization.yaml apps/beacon/
git add -A
git commit -m "Add beacon"
git push
```

The Git generator checks the repository every three minutes by default. To skip the wait, add the refresh annotation; the controller removes it again once it has refreshed:

```sh
kubectl -n argocd annotate applicationset platform-apps argocd.argoproj.io/application-set-refresh=true
kubectl -n argocd get applications -L team
```

On the playground the new application appeared within two seconds:

```text
NAME               SYNC STATUS   HEALTH STATUS   TEAM
beacon             Synced        Progressing     starfleet
bridge             Synced        Healthy         starfleet
probe              Synced        Healthy         starfleet
scout              Synced        Healthy         starfleet
scout-production   Synced        Healthy         
scout-staging      Synced        Healthy         
```

A folder in Git became a running service without a single `Application` written by hand.

## Removing a folder

The reverse works too, and it goes further than the app of apps parent did. Generated applications carry the finalizer that makes a delete cascade:

```sh
kubectl -n argocd get application beacon -o jsonpath='{.metadata.finalizers}'
```

You should see:

```text
["resources-finalizer.argocd.argoproj.io"]
```

Remove the folder from Git, push, and refresh:

```sh
git rm -r apps/beacon
git commit -m "Remove beacon"
git push
kubectl -n argocd annotate applicationset platform-apps argocd.argoproj.io/application-set-refresh=true
```

After a few seconds, `kubectl -n argocd get applications` no longer lists `beacon`, and `kubectl -n starfleet get deploy` no longer lists the `beacon` Deployment. The `ApplicationSet` deleted the `Application`, and the finalizer made Argo CD delete its objects first. That is powerful and dangerous in equal measure: a folder renamed by mistake deletes a running service. The field `spec.syncPolicy.preserveResourcesOnDeletion: true` on the `ApplicationSet` keeps the workloads when a generated `Application` is removed.

You can now generate applications from a list of values and from the folders of a repository, name and place them with Go template fields, and predict what happens when an element or folder disappears. Every generated application still uses the `default` project, which allows any repository and any namespace. The open question is how to stop one team's applications from reaching into another team's namespace.

## Common pitfalls

> [!WARNING]
> - **Unquoted placeholders.** A value starting with `{{` must be quoted, or the YAML does not parse.
> - **Leaving out `missingkey=error`.** A misspelled parameter then renders as an empty string instead of failing.
> - **Editing a generated `Application`.** The `ApplicationSet` sets it back; change the template or the generator.
> - **Renaming or removing a folder under a Git directory generator.** The generated `Application` and its workloads are deleted. Use `preserveResourcesOnDeletion` where that is not acceptable.
> - **Expecting new folders to appear at once.** The Git generator polls; use the refresh annotation to skip the wait.
