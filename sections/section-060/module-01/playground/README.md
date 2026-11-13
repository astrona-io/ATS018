# Run CI Workflows With Argo Workflows — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-060-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with
Argo Workflows v4.1.6 (namespace install in `starfleet`, no web server) and its
`argo` command-line tool, Argo
Events v1.9.11 with a one-pod JetStream `EventBus` in `argo-events`, and Gitea
with the public repository `starfleet/scout-app`. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-060-01
```

## Notes for authors

- The Workflows `namespace-install.yaml` is about 12 MB (it embeds the CRDs),
  so `bootstrap/02-install-argo-workflows.sh` applies it with
  `kubectl apply --server-side --force-conflicts`. The script deletes the
  `argo-server` Deployment and Service to save memory.
- `manifests/eventbus.yaml` sets `streamConfig` with `replicas: 1`. Without it
  the stream asks for 3 replicas and a one-pod JetStream refuses it
  ("replicas > 1 not supported in non-clustered mode"), so no event is stored.
- Workflow pods need a ServiceAccount that can create `workflowtaskresults`.
  `workflow-runner` has it; the `default` account does not, and a Workflow that
  uses `default` ends in `Error`. The course uses this as a failure to read.
- Gitea's `webhook.ALLOWED_HOST_LIST` is `private,loopback`, so Gitea can
  deliver to the `EventSource` Service.
- `run-tests` starts with `workingDir: /wrong` on purpose.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, bootstrap order, port forward) |
| `bootstrap/00-install-argo-cli.sh` | Installs the `argo` command-line tool v4.1.6 in `~/.astrona/bin` unless an `argo` is already on the `PATH` |
| `bootstrap/01-install-gitea.sh` | Starts Gitea and creates the user `platform` |
| `bootstrap/02-install-argo-workflows.sh` | Installs Argo Workflows v4.1.6 |
| `bootstrap/03-install-argo-events.sh` | Installs Argo Events v1.9.11, the `EventBus` and the Sensor RBAC |
| `bootstrap/04-seed.sh`, `seed-repo.sh` | Pushes `scout-app`, creates the push webhook, applies `run-tests` |
| `manifests/` | Namespace, `shuttle`, executor RBAC, Gitea, the `EventBus`, the Sensor RBAC, `run-tests` |
| `repos/` | Content of `scout-app` |
| `docs/overview.md` | What the environment contains and ideas to try |
