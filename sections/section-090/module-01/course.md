# Deliver Infrastructure Objects With Crossplane And GitOps

A platform team often has to give other teams a simple way to get a working environment. Writing a Deployment, a Service and the settings around them for every team does not scale. Crossplane is a Kubernetes add-on (a set of controllers and custom resource definitions) that lets the platform team define its own API for this. A team creates one small object, and Crossplane creates and maintains every object behind it.

Crossplane does not deliver anything from Git by itself. Argo CD or Flux does that. This module shows both halves: how the Crossplane objects fit together, and how a GitOps controller delivers them in the right order and reports their real health.

Keep one sentence in mind for this module: **a composite resource is Ready only when every object behind it is Ready, and a GitOps controller only knows that if you tell it how to read the status.** The module has five parts. The first installs a provider and a function. The second defines the API and creates the first environment. The third delivers it with Argo CD. The fourth finds and fixes an environment that is not Ready. The fifth delivers the same objects with Flux.

## Learning objectives

After this module you can:

- Install a `Provider` and a `Function`, and read their `Healthy` status.
- Connect a provider to the cluster with a `ClusterProviderConfig` and the permissions it needs.
- Write a `CompositeResourceDefinition` and a `Composition`, and create a composite resource from them.
- Read the `Synced` and `Ready` conditions of a composite resource and of the objects it composes.
- Deliver Crossplane objects with an Argo CD `Application` (sync waves, custom health) and with Flux `Kustomization` objects (`dependsOn`, `wait`).
- Diagnose a composite resource that is not Ready and fix it through Git.

## Before you start

You need Kubernetes basics: Deployments, Services, namespaces and `kubectl`. You also need to know what a GitOps controller does. The module explains each Crossplane term when it first appears.

The playground runs Kubernetes 1.35.8 and Crossplane 2.4.3, with only the core controller and the RBAC manager. It also runs Gitea, a small Git server, Argo CD 3.5.4 and Flux 2.9.6. Argo CD and Flux already have credentials for the repository.

| Place | What is in it |
| --- | --- |
| `crossplane-system` | The Crossplane controller and the RBAC manager. No provider and no function yet |
| `starfleet` | The `shuttle` client pod |
| `starfleet-staging` and `starfleet-production` | Empty namespaces for the two environments |
| Gitea repository `starfleet/platform-infra` | The platform API in `platform/` and one environment each in `environments/staging` and `environments/production` |

The `argocd` command-line tool reaches Argo CD on `https://127.0.0.1:8080`. Git reaches Gitea on `http://127.0.0.1:3000` with the user `platform` and the password `starfleet-gitops`. Check that `kubectl config current-context` points at the playground before you start.

<!-- astrona:playground -->
