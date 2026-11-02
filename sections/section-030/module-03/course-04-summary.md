# Summary

Flux can update the image tag in Git by itself. An `ImageRepository` makes the image reflector controller scan a registry and store the tag list in its status. The scan never pulls the image, and it needs `insecure: true` for a registry that speaks plain HTTP.

An `ImagePolicy` chooses one tag from that list. With a semver rule it picks the highest version inside a range, and it ignores tags that are not versions. A range that no tag satisfies leaves the policy not Ready with the message `unable to determine latest version from provided list`, while the scan stays Ready. The policy records the tag only. It never edits Git or a Deployment.

An `ImageUpdateAutomation` turns the chosen tag into a commit. It clones the repository through a `GitRepository` credential that can write, looks for setter marker comments under `update.path`, replaces the marked values and pushes a commit with a configured author and message. The marker names the namespace, the policy and the part to write, for example `flux-system:scout:tag`. After the push, the source and kustomize controllers deliver the commit like any change made by a person, so the release is reviewable and a revert in Git is a rollback.

When a release does not arrive, read the objects in the order of the flow: the scan, the policy, the automation run, the fetched commit and the applied Kustomization. The first one that is not Ready shows the fault. A pipeline that pushes the commit and an automation that watches the registry both end in the same place, a commit in Git that the GitOps controller delivers.

<!-- astrona:playground:destroy -->
