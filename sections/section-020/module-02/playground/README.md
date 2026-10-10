# Manage Many Applications With ApplicationSets — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-020-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with Argo CD 3.5.4 (non-HA,
Dex and notifications scaled to zero), an in-cluster Gitea (plumbing only)
holding the private repositories `starfleet/platform-apps` and
`starfleet/outpost-apps`, an Argo CD credential template for the `starfleet`
organisation, the `starfleet` namespace with `shuttle`, and an empty `outpost`
namespace. No Application, ApplicationSet or extra AppProject exists. Port
forwards: Argo CD on `https://127.0.0.1:8080`, Git on `http://127.0.0.1:3000`.
Needs outbound internet for the Argo CD install manifest. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-020-02
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, port forwards, bootstrap) |
| `bootstrap/01-install-gitea.sh` | Starts Gitea and creates the user `platform` |
| `bootstrap/02-install-argocd.sh` | Installs Argo CD 3.5.4 |
| `bootstrap/03-seed.sh`, `bootstrap/seed-repo.sh` | Pushes both repositories and adds the credential template Secret |
| `manifests/gitea.yaml` | Gitea Deployment and Service (SQLite, no cache) |
| `manifests/lab-start.yaml` | Namespaces `starfleet` and `outpost`, and the `shuttle` client |
| `repos/platform-apps/`, `repos/outpost-apps/` | Repository content |
| `docs/overview.md` | What the environment contains and ideas to try |
