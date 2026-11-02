# Prerequisites

- `kubectl` 1.35 on your `PATH`.
- Istio 1.30.7 with sidecar injection on `starfleet`, Istio's Prometheus add-on, Flagger 1.45.0 for the Istio provider and the Flagger load tester in `starfleet`. The lab installs them.
- The Deployment `scout` (podinfo 6.14.0, 1 replica), its Service and the `shuttle` client pod in `starfleet`. The lab creates them. No `Canary` exists yet.
