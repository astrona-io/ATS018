# Overview: Manage Many Applications With ApplicationSets (Playground)

This is a **playground**, not a lab. It starts a cluster with Argo CD and two private Git repositories, and then waits. There is no task, no `astrona submit` and no pass or fail. Generate applications, restrict them, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- **Argo CD 3.5.4** in `argocd`, reachable on `https://127.0.0.1:8080`. The user is `admin`; the password is in the Secret `argocd-initial-admin-secret`.
- Two **private Git repositories**, reachable from your machine on `http://127.0.0.1:3000` (user `platform`, password `starfleet-gitops`). Argo CD reaches them at `http://gitea-http.gitea.svc:3000/starfleet/...` with a credential template that covers the whole organisation:

  | Repository | Content |
  | --- | --- |
  | `platform-apps` | `apps/scout`, `apps/probe`, `apps/bridge`; `envs/staging`, `envs/production`; `argocd-apps/` with one `Application` per service |
  | `outpost-apps` | `scout/`, the `outpost` team's service |

- Namespaces `starfleet` (with the `shuttle` client) and `outpost` (empty).
- Deliberately absent: no `Application`, no `ApplicationSet`, and no `AppProject` other than `default`.

## Helpers

Paste these once in each new terminal. `argocd_login` logs the `argocd` tool in as `admin`. `refresh_appset` makes an `ApplicationSet` read Git at once instead of waiting up to three minutes.

```sh
argocd_login() {
  argocd login 127.0.0.1:8080 --username admin --insecure \
    --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
}
refresh_appset() {
  kubectl -n argocd annotate applicationset "$1" argocd.argoproj.io/application-set-refresh=true --overwrite
}
```

Use them like this: `argocd_login`, `refresh_appset platform-apps`.

## Practice tasks

- Add a third environment to the list generator and predict the `Application` name and namespace before you apply it.
- Misspell a parameter in the template (`{{.evn}}`), apply it with and without `missingkey=error`, and compare the `ApplicationSet` conditions.
- Change the Git directory generator to `apps/*` with an `exclude: true` entry for `apps/bridge`, and watch what happens to `bridge`.
- Set `preserveResourcesOnDeletion: true`, remove a folder, and check which objects remain.
- Generate the `outpost` team's application from an `ApplicationSet` with `project: outpost`, then try to point it at `platform-apps`.
