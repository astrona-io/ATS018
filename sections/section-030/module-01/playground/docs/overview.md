# Overview: Deploy An Application With Argo CD (Playground)

This is a **playground**, not a lab. It starts a cluster with Argo CD and a private Git repository, and then waits. There is no task, no `astrona submit` and no pass or fail. Create Applications, break them, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- **Argo CD 3.5.4** in the namespace `argocd`, reachable on `https://127.0.0.1:8080`. The user is `admin`; the password is in the Secret `argocd-initial-admin-secret`. Single sign-on (Dex) and the notifications controller are scaled to zero.
- A **private Git repository** at `http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git` (from your machine: `http://127.0.0.1:3000/starfleet/scout-deploy.git`), user `platform`, password `starfleet-gitops`. It holds a Kustomize base for `scout` (podinfo, port `9898`, Service port `80`) and the overlays `overlays/staging` and `overlays/production`.
- `shuttle`, a client pod with `curl`, in the namespace `starfleet`.
- Deliberately absent: no `Application`, no repository Secret, and no `starfleet-staging` or `starfleet-production` namespace.

## Helpers

Paste these once in each new terminal. `argocd_login` logs the `argocd` tool in as `admin`. `ask_scout` sends one request from `shuttle` to the `scout` Service in the namespace you name and prints the version and message.

```sh
argocd_login() {
  argocd login 127.0.0.1:8080 --username admin --insecure \
    --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
}
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s "http://scout.$1${2:+:$2}" | grep -E '"(version|message)"'
}
```

Use them like this: `argocd_login`, `ask_scout starfleet-staging`, `ask_scout starfleet-preview 9898`.

## Practice tasks

- Create an Application for `overlays/production` before you create the repository Secret. Read the condition, then fix it, and note which component wrote the message.
- Sync an Application whose destination namespace does not exist, without `CreateNamespace=true`. Then fix it by putting a Namespace manifest in Git instead of using the sync option.
- Turn on `automated` without `selfHeal`, scale the Deployment by hand, and predict the sync status before you check it.
- Remove a file from the overlay with `prune: false`, and find the object Argo CD now marks for pruning.
- Pin `targetRevision` to a commit ID instead of `main`, push a new commit, and explain why the application does not change.
