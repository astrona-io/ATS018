# Separate Flux Source, Apply And Release Failures

Flux source reconciliation, manifest application and Helm release management are separate controller operations. Read the condition on the object responsible for the failed step before changing a workload.

A GitRepository produces an artifact from a repository revision. A Kustomization selects a path from that artifact and applies it. If application resources need a namespace or API created elsewhere, a dependency expresses that ordering. Repairing a source URL cannot fix an incorrect path, and a Ready source alone cannot prove the selected workloads were applied.

A HelmRelease adds release history and recovery behavior. Inspect the failed upgrade and the rendered values before selecting a correction. Remediation settings determine whether an unsuccessful upgrade rolls back, how many retries are allowed, and whether the last failure is remediated. Keep the existing release so its history remains evidence of the repair.

After changing Git, verify that Flux fetched and applied the new revision. After repairing a HelmRelease, inspect the deployed history entry and ready replicas. Test the application through its Service in both cases. Suspending reconciliation or directly patching the Deployment can make a temporary result look healthy while leaving the declared delivery broken.
