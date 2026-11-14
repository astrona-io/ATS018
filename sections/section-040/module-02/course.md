# Deliver Helm Releases With Flux

The `scout` chart installed successfully, but its latest upgrade cannot become ready. Flux reports the failure, and the cluster still holds the last successful release. You need to read which operation failed, repair the values, and decide what the controller should do when another upgrade fails.

A Helm chart is a package of Kubernetes templates and default values. A release is one installed copy of that package, and a revision is one numbered install, upgrade or rollback. Flux uses a HelmRelease object to manage the release through its helm controller. You use Flux and Kubernetes commands to configure and inspect it.

The module has three parts. **Chart Sources And HelmRelease** reads the starting failure, selects a chart source and repairs the release with inline values. **Values And Release History** loads values from a ConfigMap and reads the installed revisions. **Remediation And Rollback** sets recovery rules, observes a failed upgrade roll back and compares the Flux objects with Argo CD.

## Learning objectives

After this module you can:

- Create a chart source and a HelmRelease with inline values.
- Read release conditions, history and failure messages.
- Configure install and upgrade remediation, including rollback.
- Load values from a ConfigMap through `valuesFrom`.
- Match Flux source and release objects to Argo CD source and delivery settings.

## Before you start

You need Kubernetes namespaces, Deployments, Services and ConfigMaps, and the commands `kubectl apply`, `kubectl get` and `kubectl exec`. A ConfigMap holds configuration values that are not secret. A Deployment keeps application pods running, and a Service gives ready pods a stable address.

The playground runs Kubernetes 1.35.8 and Flux 2.9.6. In `starfleet`, the `podinfo` OCIRepository fetches chart 6.15.0 from an Open Container Initiative (OCI) registry. The HelmRelease `scout` has a successful revision and a deliberate failed upgrade: its values set `faults.unready: true`. No remediation is configured.

`shuttle` runs in `starfleet` as a client. Podinfo images are preloaded. Use the Flux 2.9.6 command-line tool on your machine; every command runs against the playground. The source fetch needs outbound access to the chart registry.

<!-- astrona:playground -->
