# Question

Solve this question on: `terminal`

The `HelmRelease` named `scout` in the namespace `starfleet` installs the podinfo chart from the `OCIRepository` `podinfo`. Its last upgrade failed: the helm controller reports `UpgradeFailed` and the new pods never become ready. The release also has no recovery settings, so the next failed upgrade would leave the application broken.

Repair the existing `HelmRelease` `scout` and add recovery. Do not delete and recreate the `HelmRelease`, do not suspend it, and do not change the Deployment or the Pods with `kubectl edit` or `kubectl patch`: the helm controller would revert them.

When you finish, these must be true:

- The `HelmRelease` `scout` is `Ready`, the newest release revision in its history has the status `deployed`, and the Deployment `scout-podinfo` has 1 ready replica.
- A request from the `shuttle` pod to `http://scout-podinfo:9898/` returns version `6.15.0`.
- The `HelmRelease` has upgrade remediation that rolls back a failed upgrade (`strategy: rollback`), retries at least once (`retries` of 1 or more), and also remediates the last failure (`remediateLastFailure: true`).

Check your work with `astrona submit`.
