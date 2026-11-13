# Overview: Diagnose Sync And Health Failures In Argo CD (Playground)

This is a **playground**, not a lab. It starts a cluster with Argo CD and four applications that are broken on purpose, and then waits. There is no task, no `astrona submit` and no pass or fail. Diagnose, fix, break again, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35, with metrics-server. `kubectl` is already pointed at it.
- **Argo CD 3.5.4** in `argocd`, reachable on `https://127.0.0.1:8080`. The user is `admin`; the password is in the Secret `argocd-initial-admin-secret`.
- The private repository `scout-faults`, reachable from your machine on `http://127.0.0.1:3000/starfleet/scout-faults.git` (user `platform`, password `starfleet-gitops`). Argo CD already has credentials for it.
- Four applications with automated sync, prune and self-heal, each broken in a different stage:

  | Application | Namespace | Hint |
  | --- | --- | --- |
  | `scout-path` | `starfleet-path` | Its sync status is `Unknown` |
  | `scout-reject` | `starfleet-reject` | One object is `Missing` |
  | `scout-hpa` | `starfleet-hpa` | Watch `spec.replicas` over time |
  | `scout-image` | `starfleet-image` | `Synced`, but not `Healthy` |

## Helpers

Paste these once in each new terminal. `argocd_login` logs the `argocd` tool in as `admin`. `watch_replicas` prints the replica count of a Deployment every five seconds for half a minute.

```sh
argocd_login() {
  argocd login 127.0.0.1:8080 --username admin --insecure \
    --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
}
watch_replicas() {
  for i in 1 2 3 4 5 6; do
    echo "$(date +%T) replicas=$(kubectl -n "$1" get deploy "$2" -o jsonpath='{.spec.replicas}')"
    sleep 5
  done
}
```

Use them like this: `argocd_login`, `watch_replicas starfleet-hpa scout`.

## Practice tasks

- Diagnose all four applications from `kubectl -n argocd get applications` and `argocd app get` alone before you open any file in Git.
- Break `scout-path` three ways (path, revision, repository URL) and write down the last words of each `ComparisonError`.
- Fix `scout-reject` in Git without terminating the running operation, and measure how long the old retries keep going.
- Make the `PreSync` hook fail (`exit 1` in its command) and see which objects the sync still applies.
- Fix `scout-hpa` the other way: remove `replicas` from the Deployment in Git instead of using `ignoreDifferences`.
