# Build Tekton Tasks And Pipelines

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Write a Task with params, steps, results and a workspace
- Chain Tasks in a Pipeline with runAfter and pass a result from one Task to the next
- Start a PipelineRun with a PersistentVolumeClaim workspace and read its logs with tkn
- Reference a shared Task through the cluster or git resolver instead of copying it
- Diagnose a failed TaskRun from its step status and the pod logs

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Task, TaskRun, Pipeline and PipelineRun, and the pod each TaskRun creates
- Params, results and workspaces
- Pipelines, runAfter and result passing
- Resolvers for shared Tasks
- Reading a failure with tkn and kubectl

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — A PipelineRun creating TaskRuns, each a pod whose steps run as containers sharing a workspace -->

<!-- playground provides: kind cluster with Tekton Pipelines 1.17.0, the tkn CLI 0.46.1 and Gitea with repository `starfleet/scout-app` (a small source tree with a Makefile-style test script). A Task `run-tests` is installed and deliberately has a step that fails on a wrong working directory. Deliberately absent: no Pipeline, no Triggers, no registry. -->

<!-- module section-040/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
