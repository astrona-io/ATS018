# Diagnose Sync And Health Failures In Argo CD — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-020-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with the metrics-server
addon, Argo CD 3.5.4 (non-HA, Dex and notifications scaled to zero), an
in-cluster Gitea (plumbing only) holding `starfleet/scout-faults`, and four
Applications that are broken on purpose: `scout-path` (wrong path),
`scout-reject` (container port 99999), `scout-hpa` (HPA versus self-heal) and
`scout-image` (tag 6.51.0 does not exist). Port forwards: Argo CD on
`https://127.0.0.1:8080`, Git on `http://127.0.0.1:3000`. Needs outbound
internet for the Argo CD install manifest and the missing-image pull attempt.
Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-020-03
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, metrics-server addon, preloaded images, port forwards, bootstrap) |
| `bootstrap/01-install-gitea.sh` | Starts Gitea and creates the user `platform` |
| `bootstrap/02-install-argocd.sh` | Installs Argo CD 3.5.4 |
| `bootstrap/03-seed.sh`, `bootstrap/seed-repo.sh` | Pushes `scout-faults`, adds the credential template, creates the four Applications |
| `manifests/applications.yaml` | The four broken Applications |
| `manifests/gitea.yaml`, `manifests/lab-start.yaml` | Gitea, the `starfleet` namespace and `shuttle` |
| `repos/scout-faults/` | Repository content, one folder per Application |
| `docs/overview.md` | What the environment contains and ideas to try |
