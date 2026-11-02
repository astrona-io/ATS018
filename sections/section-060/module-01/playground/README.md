# Deliver Infrastructure Objects With Crossplane And GitOps — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-060-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with Crossplane 2.4.3
(core controller and RBAC manager only), Gitea 28.1.0, Argo CD 3.5.4 and
Flux 2.9.6 (source, kustomize and notification controllers). The namespaces
`starfleet`, `starfleet-staging` and `starfleet-production` exist, with
`shuttle` in `starfleet`. The Gitea repository `starfleet/platform-infra`
holds the platform API (`platform/`) and one environment each in
`environments/staging` and `environments/production`. Production asks for a
podinfo tag that does not exist, on purpose. No `Provider`, `Function`, XRD or
`Composition` is installed. Nothing to submit.

The Argo CD repository Secret `repo-platform-infra` and the Flux Secret
`platform-infra-auth` already hold the Gitea credentials. Helm 4.3.0 is
plumbing: it installs Crossplane, Gitea and Argo CD, and is put on the `PATH`
when missing. Bootstrap scripts need outbound internet for the charts and
the Flux install manifest. The packages (`provider-kubernetes` v1.4.1 and
`function-patch-and-transform` v0.11.2) download when the learner installs
them.

## Run it

```sh
astrona run -c sections/section-060/module-01/playground --trust
astrona destroy ats-018-playground-060-01
```

Run from the course root.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, images, port forwards, initialization and readiness checks |
| `bootstrap/00-lab-start.sh` | Creates the namespaces and `shuttle` |
| `bootstrap/01-install-gitea.sh`, `02-install-argocd.sh`, `03-install-crossplane.sh`, `04-install-flux.sh` | Install the tools |
| `bootstrap/05-seed.sh` | Seeds `starfleet/platform-infra` and creates the repository credentials |
| `repos/platform-infra/` | Content of the Gitea repository |
| `docs/overview.md` | Environment contents, helpers and practice tasks |
