# Deliver Helm Releases With Flux — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-030-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no task, no grading

Kubernetes 1.35 with Flux 2.9.6. Bootstrap installs one good podinfo release,
then starts an upgrade with a broken readiness probe and no remediation.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-030-02
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime and bootstrap order |
| `bootstrap/` | Controllers and failed upgrade |
| `manifests/` | Client and initial release |
| `docs/overview.md` | Environment and practice tasks |
