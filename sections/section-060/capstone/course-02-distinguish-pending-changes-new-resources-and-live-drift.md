# Distinguish Pending Changes, New Resources And Live Drift

An OpenTofu plan compares configuration with refreshed infrastructure and the recorded resource identities. Three changes can look similar from the application but require different reviews: an unapplied configuration update, a resource that has never been managed, and a manual change to an existing managed resource.

For a pending replica change, expect an in-place Deployment update. For a new Service, expect creation of that Service while the Deployment remains unchanged. For live drift, refresh reveals the actual replica count and the plan restores the configured count. Replacing the Deployment is not equivalent to preserving its managed identity.

Keep each working directory’s state and provider configuration separate. Resource addresses connect configuration blocks to recorded objects. Copying state between directories or editing it to silence a difference destroys the basis of the comparison.

Save the plan before applying it, and retain its readable display. Apply the saved plan so the executed operations match the review. Afterwards, inspect the Deployment and Service identities and request the Service from the client Pod.

Finally, produce a fresh plan. No remaining changes, the expected updated and available replicas, and a correct application response establish different parts of the result. Ignoring a changed field can make the plan quiet without repairing the live resource.
