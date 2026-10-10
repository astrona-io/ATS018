# Automate Canary Analysis With Flagger

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Create a Canary resource that targets a Deployment and read the primary and canary objects Flagger creates
- Configure the analysis interval, threshold, stepWeight and maxWeight with the built-in request-success-rate metric
- Trigger a canary by changing the Deployment image and follow it in the Canary status and events
- Generate test traffic during analysis with the Flagger load tester webhook
- Compare how Flagger and Argo Rollouts each take over a workload

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- What Flagger does with a Deployment and the objects it generates
- The Canary resource and its analysis block
- A promoted and a rolled back canary
- Load testing webhooks
- Flagger and Argo Rollouts side by side

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Flagger reading metrics and shifting the mesh traffic weight between the primary and canary Deployments -->

<!-- playground provides: kind cluster with Istio 1.31.1 (minimal profile, sidecar injection on `starfleet`), Flagger 1.45.0 for the Istio provider with its bundled Prometheus, and the flagger-loadtester in `starfleet`. `scout` runs as a plain Deployment with a Service. Deliberately absent: no Canary resource and no Argo Rollouts in this cluster. -->

<!-- module section-050/module-03 (Module 3) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
