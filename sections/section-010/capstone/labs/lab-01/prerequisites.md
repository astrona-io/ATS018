# Prerequisites

- `kubectl` 1.35 with the Kustomize built into it (`kubectl kustomize`, `kubectl apply -k`, `kubectl diff -k`).
- The namespaces `starfleet`, `starfleet-staging` and `starfleet-production`, and the `shuttle` client pod in `starfleet`. The lab creates them.
- The broken `scout` folder. `astrona run` copies it to `~/resources/scout` in the lab terminal.
