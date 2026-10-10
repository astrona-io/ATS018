# Reconcile Git Sources With Flux Kustomizations

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-030/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Install the Flux controllers and check them with flux check
- Create a GitRepository source and a Flux Kustomization that applies a path with prune enabled
- Read the Ready condition of sources and Kustomizations with flux get and kubectl describe
- Force a reconcile and suspend and resume a Kustomization
- Order two Kustomizations with dependsOn

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- The Flux controllers and their split into sources and appliers
- GitRepository and the artifact it produces
- The Flux Kustomization (path, interval, prune, targetNamespace)
- Reading status with the flux CLI
- Reconcile, suspend, resume and dependsOn

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — The source controller producing an artifact that the kustomize controller applies -->

<!-- playground provides: kind cluster with the flux CLI 2.9.6 and the Flux controllers installed (no bootstrap), and Gitea with repository `starfleet/scout-deploy` (Kustomize base and overlays) and a read-only credential Secret ready in `flux-system`. Deliberately absent: no GitRepository or Kustomization; no Argo CD in this cluster. -->

<!-- module section-030/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
