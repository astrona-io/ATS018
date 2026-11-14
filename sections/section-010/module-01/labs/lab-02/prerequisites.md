# Prerequisites

- `kubectl` 1.35 with the Kustomize built into it (`kubectl kustomize`, `kubectl apply -k`, `kubectl diff -k`).
- The namespaces `starfleet` and `starfleet-staging`, and the `shuttle` client pod in `starfleet`. The lab creates them.
- The `scout` folder with a finished base and an unfinished staging overlay. `astrona run` copies it to `~/resources/scout` in the lab terminal.
- The node preloads podinfo `6.14.0` and `6.15.0` and `curlimages/curl:8.22.0`.
