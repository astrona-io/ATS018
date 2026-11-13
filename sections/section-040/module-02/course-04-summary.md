# Summary

Flux separates chart fetching from release management. An OCIRepository publishes a chart artifact directly. A HelmRepository supplies a chart repository index, which a HelmRelease uses to select a chart and version. Source readiness proves the package was fetched, while HelmRelease readiness describes the install or upgrade result.

A HelmRelease holds chart references, values, timeouts and remediation rules. Inline values override values loaded through `valuesFrom`. A ConfigMap can hold a shared values document, and a watch label lets its changes request reconciliation. The helm controller renders those values and changes the workload; the ConfigMap does not change pods directly.

History records numbered release revisions separately from chart versions. A values-only change can create a new revision of the same chart. Read each record's revision and status; a failed upgrade can leave an older successful revision deployed, and rollback history need not be sorted numerically.

Install remediation removes a failed install before retrying. Upgrade remediation can roll back to the last successful configuration. Retries count extra attempts, and final remediation can restore a working application after that budget is exhausted. Ready stays false while the current desired values still fail, even when Remediated is true and client requests succeed.

Fix the desired values before requesting another attempt. A reset clears failure counters; it cannot repair the configuration. Flux release management also differs from Argo CD chart delivery: Argo CD renders and syncs manifests, while the Flux helm controller manages release operations and their history.

<!-- astrona:playground:destroy -->
