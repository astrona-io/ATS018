# Manage Many Applications With ApplicationSets

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-020/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Bootstrap several Applications from one parent Application with the app of apps pattern
- Generate one Application per environment with an ApplicationSet list generator
- Generate one Application per directory with the ApplicationSet git generator
- Name and place generated Applications with Go template fields
- Restrict a tenant's source repositories and destination namespaces with an AppProject

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Why one Application per service does not scale
- App of apps and its limits
- ApplicationSet, generators and the template
- List and git directory generators with Go templates
- AppProject restrictions for a second tenant

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — An ApplicationSet generator producing parameters that fill the template into several Applications -->

<!-- playground provides: kind cluster with Argo CD 3.5.4 and Gitea. Repository `starfleet/platform-apps` holds directories `apps/scout`, `apps/probe` and `apps/shuttle`, each a Kustomize base, plus `envs/staging` and `envs/production`. A second tenant namespace `outpost` exists. The default AppProject is the only project. Deliberately absent: no ApplicationSet, no AppProject for `outpost`. -->

<!-- module section-020/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
