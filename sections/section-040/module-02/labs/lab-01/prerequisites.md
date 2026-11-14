# Prerequisites

- `kubectl` 1.35 and the `flux` command-line tool.
- Flux 2.9.6 with the helm controller in the namespace `flux-system`. The lab installs it.
- The `OCIRepository` `podinfo` and the `HelmRelease` `scout` (podinfo chart 6.15.0) in the namespace `starfleet`. The lab creates them and makes the latest upgrade of `scout` fail.
- The `shuttle` client pod in the namespace `starfleet`.
