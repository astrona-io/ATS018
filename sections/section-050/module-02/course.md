# Gate A Blue/Green Release With Analysis

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Configure a blueGreen strategy with activeService, previewService and autoPromotionEnabled set to false
- Test the new version through the preview Service before promotion
- Write an AnalysisTemplate that queries Prometheus for the success rate of the new version
- Run the analysis as prePromotionAnalysis and read the AnalysisRun result
- Prove that a failing metric aborts the release and keeps the old version active

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Blue/green with an active and a preview Service
- Manual promotion and scale-down delay
- AnalysisTemplate, AnalysisRun and the Prometheus provider
- Pre-promotion and post-promotion analysis
- A failed analysis and what stays active

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — A blue/green release with pre-promotion analysis querying Prometheus and promoting or aborting -->

<!-- playground provides: kind cluster with Argo Rollouts 1.10.0 and a small Prometheus (kube-prometheus-stack 92.3.0 trimmed to Prometheus and the operator) scraping `scout` in `starfleet`. `scout` runs podinfo 6.15.0 as a Rollout with a blueGreen strategy and no analysis. A second podinfo configuration that returns random 500 errors is ready to deploy as the bad version. `shuttle` sends steady traffic. -->

<!-- module section-050/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->
