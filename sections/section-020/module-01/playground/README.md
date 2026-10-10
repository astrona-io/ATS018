# Deploy An Application With Argo CD — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with Argo CD 3.5.4 (non-HA,
Dex and notifications scaled to zero), an in-cluster Gitea (plumbing only)
holding the private repository `starfleet/scout-deploy`, and the `shuttle`
client in `starfleet`. No Application and no repository Secret exist, on
purpose. Port forwards: Argo CD on `https://127.0.0.1:8080`, Git on
`http://127.0.0.1:3000`. Needs outbound internet for the Argo CD install
manifest and the podinfo chart. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-020-01
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, port forwards, bootstrap) |
| `bootstrap/01-install-gitea.sh` | Starts Gitea and creates the user `platform` |
| `bootstrap/02-install-argocd.sh` | Installs Argo CD 3.5.4 |
| `bootstrap/03-seed.sh`, `bootstrap/seed-repo.sh` | Pushes `repos/scout-deploy` into Gitea |
| `manifests/gitea.yaml` | Gitea Deployment and Service (SQLite, no cache) |
| `manifests/lab-start.yaml` | The `starfleet` namespace and the `shuttle` client |
| `repos/scout-deploy/` | Repository content: Kustomize base and staging/production overlays |
| `docs/overview.md` | What the environment contains and ideas to try |
