# Reconcile Git Sources With Flux Kustomizations — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

Kubernetes 1.35 with Flux 2.9.6, a private deployment repository and the
`shuttle` client. The learner creates the source and the appliers.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-030-01
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime and bootstrap order |
| `bootstrap/` | Controller installation and repository preparation |
| `manifests/` | Initial namespaces and client |
| `repos/` | Initial repository content |
| `docs/overview.md` | Environment and practice tasks |
