# Question

Solve this question on: `terminal`

Release `scout` in `starfleet-production` has three revisions. Revision 1 used podinfo 6.14.0. Revision 2 deployed two replicas of 6.15.0 with message `release-ready`. Revision 3 changed the message to `temporary`. The chart is already complete; recover the working release from its stored history.

## Tasks

1. Inspect `helm history` and the values stored in revisions 2 and 3. Confirm the current response from `shuttle` in `starfleet`.
2. Roll back to revision 2 using Helm. Wait for the release to be deployed and both replicas to be ready.
3. Confirm that history records the rollback and that `http://scout.starfleet-production/` returns version `6.15.0` and message `release-ready` from `shuttle`.

## Constraints

- Preserve the release and its history. Do not uninstall it, edit its storage Secrets or patch the Deployment directly.
- Keep the image repository, selectors and readiness probe unchanged.

Learner work: about 10 minutes. Cluster startup and the seeded release rollouts take additional time.
