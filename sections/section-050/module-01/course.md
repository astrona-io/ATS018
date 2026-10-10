# Roll Out A Canary With Argo Rollouts

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Convert a Deployment into a Rollout with canary steps (setWeight and pause)
- Follow a canary with kubectl argo rollouts get rollout --watch
- Promote, pause and abort a rollout and name the ReplicaSet that serves traffic
- Explain how Argo Rollouts approximates a weight with replica counts when no traffic router is configured
- Retry an aborted rollout after the image is fixed

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Why a Deployment rolling update is not a canary
- The Rollout resource and the canary strategy steps
- The kubectl argo rollouts plugin and its status view
- Promote, pause, abort and retry
- Weights without a traffic router

## Diagrams planned

<!-- TODO(build): mermaid `state` — Rollout phases (Progressing, Paused, Healthy, Degraded) through promote and abort -->
<!-- TODO(build): mermaid `flowchart` — Stable and canary ReplicaSets behind one Service and the replica split per step -->

<!-- playground provides: kind cluster with the Argo Rollouts 1.10.0 controller and the kubectl argo rollouts plugin. Namespace `starfleet` holds `scout` as a Deployment (podinfo 6.14.x) with 5 replicas and a Service, and `shuttle`. Deliberately absent: no Rollout, no traffic router, no metrics provider. -->

<!-- module section-050/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
