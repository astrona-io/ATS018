# Deliver Helm Releases With Flux

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-030/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Create an OCIRepository or HelmRepository source and a HelmRelease with inline values
- Read HelmRelease status and history and find why an install or upgrade failed
- Configure install and upgrade remediation so a failed upgrade rolls back
- Load values from a ConfigMap with valuesFrom
- Match each Flux object to the Argo CD object that does the same job

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Helm sources in Flux (HelmRepository, OCIRepository)
- The HelmRelease resource and its values
- Status, history and failure messages
- Remediation, retries and rollback
- Flux and Argo CD side by side

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — The helm controller installing, failing an upgrade and remediating with a rollback -->

<!-- playground provides: kind cluster with the Flux controllers, outbound internet to ghcr.io, and a HelmRelease `scout` in `starfleet` (podinfo chart) that is deliberately failing: its values set a readiness probe path that never answers, so the upgrade times out. No remediation is configured yet. -->

<!-- module section-030/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
