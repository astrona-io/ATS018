# Summary

A canary release keeps a stable application serving while a new version receives a limited share of traffic. Argo Rollouts manages that release through a `Rollout`, a custom Kubernetes resource that creates and scales ReplicaSets. A ReplicaSet keeps pods running from one template. The initial Rollout establishes its stable template without stopping at the canary steps.

## What you learned

A template change starts the canary steps. `setWeight` requests the new version's share, and `pause` stops release progress while ready pods keep serving. Without a traffic router, a component that controls request shares, the controller approximates each weight with whole replica counts. Five replicas give a one-new, four-stable split at 20%, and a three-new, two-stable split at 60%. A short request sample need not match those ratios.

Promotion advances a pause. An explicit `spec.paused` field and a canary pause are separate controls: clearing the explicit pause can leave a step pause to clear. Full promotion skips remaining steps and checks. A complete release reports Healthy and makes the new template stable.

An abort reports Degraded, scales the canary down and keeps the stable version serving. It does not correct the desired pod template. A new template starts a new release, while retry allows another attempt at the same aborted template. Read the release status, the ReplicaSet counts and the application response together before deciding that recovery is complete.

<!-- astrona:playground:destroy -->
