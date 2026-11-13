# Automate Canary Analysis With Flagger — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-080-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with Istio 1.30.7
(`istiod` only, sidecar injection on `starfleet`), Istio's Prometheus add-on,
Flagger 1.45.0 for the Istio provider and the Flagger load tester 0.39.0.
`scout` starts as a plain Deployment (podinfo 6.14.0, one replica) with a
Service. `shuttle` is the client. No `Canary` exists. Nothing to submit.

The Istio 1.31.x Helm charts are not published, so the playground uses the
newest final chart, 1.30.7. Bootstrap scripts need outbound internet for the
charts and the Prometheus add-on manifest. Helm 4.3.0 is plumbing and is put
on the `PATH` when missing.

## Run it

```sh
astrona run -c sections/section-080/module-01/playground --trust
astrona destroy ats-018-playground-080-01
```

Run from the course root. Initialization applies the starting workloads
before it turns on sidecar injection, because Astrona runs initialization
scripts before its manifest stage.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, images, initialization and readiness checks |
| `bootstrap/01-install-istio-flagger.sh` | Applies the workloads, installs Istio, its Prometheus, Flagger and the load tester |
| `manifests/lab-start.yaml` | Namespace, `scout`, its Service and `shuttle` |
| `docs/overview.md` | Environment contents, helpers and practice tasks |
