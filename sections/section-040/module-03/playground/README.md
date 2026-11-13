# Automate Image Updates With Flux — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-040-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

Kubernetes 1.35 with Flux 2.9.6 and its image reflector and image automation
controllers, Gitea (plumbing) with the repository `starfleet/scout-deploy`, an
in-cluster registry that holds `starfleet/scout:6.14.0` and `6.15.0`, and the
`shuttle` client. Flux already delivers `scout` 6.14.0 from Git. The learner
creates the `ImageRepository`, `ImagePolicy` and `ImageUpdateAutomation`.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-040-03
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime and bootstrap order |
| `bootstrap/` | Gitea, registry, Flux and repository preparation |
| `manifests/` | Namespaces, client, Gitea, registry and the Flux delivery of `scout` |
| `repos/` | Initial content of `starfleet/scout-deploy` |
| `docs/overview.md` | Environment and practice tasks |
