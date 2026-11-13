# Tell Three Kinds Of Plan Changes Apart

An OpenTofu plan can propose a change for three different reasons. The configuration changed and nobody applied it yet. The configuration names a resource that state does not record yet. Or someone changed a managed resource by hand. All three show up as a difference in the plan, but each one needs a different review. This part shows how to tell them apart before you apply.

## What the plan compares

OpenTofu builds a plan from three inputs. The configuration is the `.tf` files: they say what should exist. The state file records which real object belongs to each resource address, for example `kubernetes_deployment.scout`. During the plan, OpenTofu also reads the live object from the Kubernetes API. This step is called refresh.

The plan is the difference between the configuration and the refreshed live object. Each changed resource gets a symbol in the plan: `+` means create, `~` means update in place, `-` means destroy, and `-/+` means destroy and create again (replace). The last line of the plan counts the resources to add, change and destroy.

## Three changes that look alike

The first kind is a pending update. Someone changed an attribute in the configuration, for example `replicas` from `1` to `2`, and did not apply it. The plan shows `~` on the Deployment with the old and the new value. State and the live object still agree with each other. Apply the saved plan to finish the change.

The second kind is a new resource. The configuration has a resource block, for example a `kubernetes_service`, that state does not record. The plan shows `+` for the Service and no change for the Deployment. If the plan also shows a change on the Deployment, read it before you apply: the new resource should not touch the existing one.

The third kind is live drift. Drift is a difference between the live object and the configuration, for example after `kubectl scale`. The configuration did not change, but refresh reads the new live value. The plan shows `~` on the Deployment and sets the value back to the one in the configuration. OpenTofu repairs drift only when you apply. It does not watch the cluster between commands.

## Keep the identity of each resource

In all three cases, the existing Deployment must stay the same object. A plan line with `-/+` on the Deployment means OpenTofu would delete it and create a new one. Pods restart, and the old object is gone. Read the plan for `-/+` before you apply, and find which attribute forces the replacement.

Each working directory has its own state and provider settings. The resource address in one directory says nothing about another directory. Do not copy a state file from one directory to another, and do not edit state to make a difference go away. Do not add a changed field to `ignore_changes` in a `lifecycle` block either. The plan then stays quiet, but the live object stays wrong.

## Save, apply and check again

Save the plan with `tofu plan -out=change.plan`, and save a readable copy with `tofu show -no-color change.plan > plan.txt`. Apply the saved file with `tofu apply change.plan`, so OpenTofu runs exactly the change you reviewed. Then run `tofu plan` once more. A plan with no changes proves that configuration, state and the live object agree.

You now know how to read a plan for the reason behind each change: a pending update, a new resource or live drift. A quiet plan is only part of the proof. The open question is whether the workload answers, so also check the ready replicas and send a request to the Service from a client pod.

## Common pitfalls

> [!WARNING]
> Drift and a pending update both show `~` on the same resource. Check
> whether the configuration changed or the live object changed. A `-/+` on an
> existing Deployment replaces it; do not apply that plan without finding the
> cause. Never copy or edit state, and never hide a difference with
> `ignore_changes`.
