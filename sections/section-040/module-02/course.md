# Hand Off From A Tekton Pipeline To GitOps

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Push a newly tagged image to the in-cluster registry from a pipeline Task
- Update the image tag in a GitOps repository from a pipeline with a Git commit
- Give a Task Git credentials through a Secret and a service account
- Start a PipelineRun from a Git push with an EventListener, a TriggerBinding and a TriggerTemplate
- Prove the full flow from a push to a PipelineRun, a commit and an Argo CD sync of the new version

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- The CI to GitOps hand-off and why the pipeline never applies to the cluster
- Publishing an image tag to the in-cluster registry
- Committing the new tag with credentials from a Secret
- Tekton Triggers (EventListener, TriggerBinding, TriggerTemplate) and a Gitea webhook
- Following one change end to end

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — A Git push through the webhook, EventListener, PipelineRun, registry, GitOps commit and Argo CD sync -->

<!-- playground provides: kind cluster with Tekton Pipelines 1.17.0 and Triggers 0.36.4, an in-cluster OCI registry, Gitea with `starfleet/scout-app` and `starfleet/scout-deploy`, and Argo CD 3.5.4 with an Application `scout` that auto-syncs `scout-deploy` into `starfleet`. Deliberately absent: no Gitea webhook, no EventListener and no Git credential Secret for the pipeline. -->

<!-- module section-040/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
