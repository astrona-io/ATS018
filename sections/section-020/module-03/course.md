# Diagnose Sync And Health Failures In Argo CD

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-020/module-03/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Read the sync result and the per-resource messages of a failed sync with argocd app get
- Find why an Application stays OutOfSync with argocd app diff and ignore a field another controller changes with ignoreDifferences
- Order dependent resources with sync waves and run a PreSync hook Job
- Diagnose a ComparisonError caused by a wrong repository URL, revision or path
- Recover a Degraded Application by fixing the Git repository instead of the cluster

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Where Argo CD reports a problem (conditions, operation state, resource status)
- Fetch and render failures (ComparisonError)
- Sync failures (rejected manifests, missing namespaces, ordering) and sync waves and hooks
- Permanent drift and ignoreDifferences
- Health failures and why the fix belongs in Git

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — A decision tree from the Application status to the failing stage (fetch, render, sync, health) -->
<!-- TODO(build): mermaid `state` — Sync status and health status combinations an Application moves through during a failed and a repaired sync -->

<!-- playground provides: kind cluster with Argo CD 3.5.4 and Gitea. Four Applications are deliberately broken: one with a wrong path (ComparisonError), one with a manifest the API server rejects (sync failed), one whose Deployment replicas are changed by a HorizontalPodAutoscaler (permanent OutOfSync), and one that references an image tag that does not exist (Degraded). The Git repository is writable by the reader through the Gitea web UI and git over HTTP. -->

<!-- module section-020/module-03 (Module 3) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
