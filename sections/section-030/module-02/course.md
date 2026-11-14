# Manage Many Applications With ApplicationSets

One `Application` per service is easy to read and easy to write. With three services in two environments it is already six objects that are almost the same, and a platform with fifty services and four environments needs two hundred. Copying them by hand brings back the drift that GitOps was meant to remove, only now in the Argo CD objects themselves.

Argo CD has two answers. The older one, called "app of apps", keeps `Application` manifests in Git and lets one parent `Application` deliver them. The newer one, the `ApplicationSet`, generates `Application` objects from a template and a generator, so adding a service or an environment is one line or one folder. On a shared platform, a third object keeps teams apart: the `AppProject` limits which repositories and namespaces a group of applications may use.

Keep one sentence in mind for this module: **an ApplicationSet owns the Applications it generates, and an AppProject limits what any Application may do.** The first makes many applications cheap, and the second makes them safe to hand to another team.

The module has three parts. **App Of Apps** delivers three `Application` objects from Git through one parent and shows where the pattern stops helping. **ApplicationSets And Generators** generates one `Application` per environment with a list generator and one per folder with a Git directory generator, using Go templates for names and paths. **AppProjects For A Second Tenant** limits the `outpost` team to its own repository, namespace and resource kinds, and reads the errors Argo CD gives when a rule is broken.

## Learning objectives

After this module you can:

- Bootstrap several Applications from one parent `Application` with the app of apps pattern.
- Generate one `Application` per environment with an `ApplicationSet` list generator.
- Generate one `Application` per folder with the `ApplicationSet` Git directory generator.
- Name and place generated Applications with Go template fields.
- Restrict a tenant's source repositories, destination namespaces and resource kinds with an `AppProject`.

## Before you start

You need to know the `Application` resource: its `source` (repository, revision, path), its `destination` (cluster, namespace) and its `syncPolicy`, and how to read sync status and health status with `argocd app get`. You also need `git` and the `argocd` command-line tool version 3.5.

Your playground is a single-node `kind` cluster running Kubernetes 1.35 with Argo CD 3.5.4 in `argocd`, reachable on `https://127.0.0.1:8080` (user `admin`, password in the Secret `argocd-initial-admin-secret`). Two private Git repositories live on an in-cluster Git server, reachable from your machine on `http://127.0.0.1:3000` with the user `platform` and the password `starfleet-gitops`:

| Repository (in-cluster address) | What it holds |
| --- | --- |
| `http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git` | `apps/scout`, `apps/probe`, `apps/bridge` (one Kustomize folder per service), `envs/staging` and `envs/production` (`scout` per environment), and `argocd-apps/` (one `Application` manifest per service) |
| `http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git` | `scout/`, the `outpost` team's copy of `scout` |

Argo CD already has a credential template for every repository under `http://gitea-http.gitea.svc:3000/starfleet`, so no repository Secret is needed. The namespaces `starfleet` (with the `shuttle` client) and `outpost` exist. No `Application`, no `ApplicationSet` and no `AppProject` other than `default` exist yet. `kubectl` already points at the cluster.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
