# Prerequisites

- Use the lab terminal with Bash, `kubectl` 1.35, `curl` and standard archive and checksum utilities. Helm 4.3.0 is installed by bootstrap in `~/.astrona/bin`.
- Know Kubernetes namespaces, Deployments, Services, labels and readiness probes. Know that Helm templates read values and that release revisions record operations.
- Bootstrap creates `starfleet`, `starfleet-staging` and `starfleet-production`, starts the `shuttle` request client and copies starter files to `~/resources`.
- The node preloads podinfo `6.14.0` and `6.15.0` and `curlimages/curl:8.22.0`. No application release or overlay is deployed at startup.
