# Question

Solve this question on: `terminal`

The `scout` application in the namespace `starfleet` is a Deployment with one replica of podinfo `6.14.0` and a Service `scout`. The namespace has Istio sidecar injection, Flagger is installed for the Istio provider, and the Flagger load tester is reachable at `http://flagger-loadtester.starfleet/`. No `Canary` exists.

Let Flagger release `scout` with a canary analysis, then prove it protects users. Do not lower the success-rate minimum or the failure threshold to push a bad release through, and do not edit the objects Flagger generates (`scout-primary`, the extra Services, the `VirtualService`).

When you finish, these must be true:

- A `Canary` named `scout` in `starfleet` uses the provider `istio` and targets the Deployment `scout`. The Service has port `80` and `targetPort` `http`.
- Its analysis checks every `15s`, allows `3` failed checks (`threshold: 3`), moves the weight in steps of `10` up to `maxWeight: 50`, and has the built-in metric `request-success-rate` with a minimum of `99`. A `rollout` webhook calls the load tester so the canary receives requests: `hey -z 1m -q 10 -c 2 http://scout-canary.starfleet/`.
- The image `ghcr.io/stefanprodan/podinfo:6.15.0` was released and promoted.
- A faulty template was released next: the `scout` container command was `./podinfo --port=9898 --random-error`. Flagger measured a low success rate, rolled the release back and the primary pods kept serving `6.15.0`.
- Last, a fixed template was released and promoted: the faulty command is removed and the environment variable `PODINFO_UI_MESSAGE` is `fixed`.
- The `Canary` is `Succeeded`, the Deployment `scout-primary` runs `6.15.0`, and a request from the `shuttle` pod (container `shuttle`) to `http://scout.starfleet/` returns the message `fixed`.

Wait until the `Canary` is `Initialized`, and about one more minute for the first metrics, before you release the first image. A release started earlier can roll back because Flagger finds no metric values.

Check your work with `astrona submit`.
