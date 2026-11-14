# Question

Solve this question on: `terminal`

Argo CD Application `scout-hpa` syncs the `hpa` directory of the private `starfleet/scout-faults` repository. Git declares one Deployment replica, while the HPA in `starfleet-hpa` maintains at least two. Automated sync with self-heal repeatedly competes with the HPA.

## Tasks

1. Compare the Git replica declaration, the live Deployment and the HPA. Inspect the Application's sync status and identify which controller should own the replica count.
2. Configure a narrowly scoped `ignoreDifferences` rule for `/spec/replicas` on Deployment `scout` in `starfleet-hpa`. Make Argo CD respect that exception during sync as well as comparison.
3. Confirm that the Application becomes Synced while the HPA keeps at least two ready replicas. Keep ordinary Git updates and self-heal working for every other field.

## Constraints

- Preserve the Application, its source, destination and project, and the HPA's UID and specification.
- Keep automated sync, prune and self-heal enabled. Retain `CreateNamespace=true` and add only the required sync option.
- Keep Git's `replicas: 1` declaration; the task is to establish field ownership through Application configuration.
- Ignore only the named Deployment's replica field. Do not disable reconciliation or widen the exception.

The grader pushes an unrelated annotation to the lab's Git repository, verifies a real sync, then changes the live annotation and verifies self-heal. These checks leave the harmless annotation in Git. Learner work: about 15 minutes; controller startup and reconciliation take additional time.
