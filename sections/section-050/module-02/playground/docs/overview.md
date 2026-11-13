# Overview: Hand Off From A Tekton Pipeline To GitOps (Playground)

This is a **playground**, not a lab. It starts a cluster with Tekton, a registry, two Git repositories and Argo CD, and then waits. There is no task, no `astrona submit` and no pass or fail. Build the release pipeline, connect it to Git, break it, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it.
- **Tekton Pipelines 1.17.0** and **Tekton Triggers 0.36.4** (controller, webhook and core interceptors) in `tekton-pipelines`.
- A **container registry** at `registry.registry.svc:5000` inside the cluster, over plain HTTP. It holds the podinfo base images `starfleet/podinfo:6.14.0`, `6.14.1` and `6.15.0`, and `starfleet/scout:6.14.0`. The node pulls images from the same address. Read it from `shuttle` with `curl http://registry.registry.svc:5000/v2/starfleet/scout/tags/list`.
- Two **private Git repositories** at `http://gitea-http.gitea.svc:3000` (from your machine: `http://127.0.0.1:3000`), user `platform`, password `starfleet-gitops`:
  - `starfleet/scout-app`: the source. Its `VERSION` file says `6.14.0`.
  - `starfleet/scout-deploy`: the GitOps repository, a Deployment, a Service and a `kustomization.yaml` whose `newTag` sets the `scout` image tag.
- **Argo CD 3.5.4** in `argocd`, reachable on `https://127.0.0.1:8080`, user `admin`, password in the Secret `argocd-initial-admin-secret`. The `Application` `scout` syncs `scout-deploy` into `starfleet` with automated sync, prune and self-heal.
- In `starfleet`: `scout` (version `6.14.0`), `shuttle` (a client pod with `curl`), and the Task `fetch-source`, which clones a repository at a revision into the workspace `source` and reports the results `commit` and `version`.
- Deliberately absent: no Git credential Secret for the pipeline, no `EventListener`, and no webhook on `scout-app`.

## Helpers

Paste these once in each new terminal. `argocd_login` logs the `argocd` tool in as `admin`. `ask_scout` sends one request from `shuttle` to `scout` and prints its version. `show_scout_tags` lists the `scout` tags in the registry. `show_last_release` prints the status and logs of the newest PipelineRun.

```sh
argocd_login() {
  argocd login 127.0.0.1:8080 --username admin --insecure \
    --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
}
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet | grep '"version"'
}
show_scout_tags() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s http://registry.registry.svc:5000/v2/starfleet/scout/tags/list
}
show_last_release() {
  tkn -n starfleet pipelinerun describe --last
  tkn -n starfleet pipelinerun logs --last
}
```

## Practice tasks

- Run the `fetch-source` Task against `scout-app` with the `default` service account, read the error, then fix it without changing the Task.
- Write a Task that sets the image tag in `scout-deploy` and pushes a commit. Run it twice with the same version and make sure the second run succeeds without an empty commit.
- Chain clone, publish and commit in one Pipeline. Ask for a version the registry has no base image for, and check that `scout-deploy` gets no commit.
- Add an `EventListener` with a `cel` filter for pushes to `main`, connect a webhook, and push a new `VERSION`. Prove the release with `tkn`, `argocd app get` and a request from `shuttle`.
- Push to another branch and show that no PipelineRun starts.
