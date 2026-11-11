# Coverage review

ATS018 was compared with the coverage approach in ATS020: short independent tasks, explicit preparation, observable results, and a fresh-environment test that rejects unfinished work before applying the reference solution. The courses teach different domains, so ATS020 provides the review method rather than a list of topics to copy.

The review checked both directions: whether practical reading outcomes have graded exercises, and whether every lab has earlier teaching for the operations it requires. Before this change, five practical readings had no module-lab link. Two more readings had links but left distinct procedures unassessed. The requested parameterized Deployment workflow was also missing: existing resource-template examples created ConfigMaps and ServiceAccounts.

## Added exercises

| Missing practice | Preparation | New lab and evidence |
| --- | --- | --- |
| Argo CD Helm sources | 020/01, Helm Charts As A Source | [Helm source](sections/section-020/module-01/labs/lab-02/question.md): chart/version/values, Argo CD ownership, ready replicas and the application response |
| App of apps | 020/02, App Of Apps | [Parent Application](sections/section-020/module-02/labs/lab-02/question.md): parent tracking, three healthy children and their live workloads |
| Git directory generation | 020/02, ApplicationSets And Generators | [Directory generator](sections/section-020/module-02/labs/lab-03/question.md): generated names/paths, ApplicationSet owner UIDs, a fourth service added through Git |
| PreSync hooks and sync waves | 020/03, Sync Failures, Waves And Hooks | [Ordered sync](sections/section-020/module-03/labs/lab-03/question.md): successful hook in the Application operation, Job logs, tracked ConfigMap in wave -1 |
| Cluster and Git Task resolvers | 040/01, Shared Tasks With Resolvers | [Resolver repair](sections/section-040/module-01/labs/lab-03/question.md): corrected references, successful PipelineRun and Git provenance matching the tested source commit |
| Parameterized Deployment creation | 040/03, new Deployment resource-template reading | [Workflow inputs](sections/section-040/module-03/labs/lab-04/question.md): four inputs, two CLI submissions, successful resource nodes, Workflow UID annotations, ready Deployments and live responses |
| Approval after canary analysis | 050/03, Wait For Approval Before Promotion | [Promotion approval](sections/section-050/module-03/labs/lab-04/question.md): WaitingPromotion, live-event evidence captured before approval, successful promotion and the new application version |
| Crossplane delivery through Flux | 060/01, Deliver The Platform With Flux | [Flux delivery](sections/section-060/module-01/labs/lab-02/question.md): dependency ordering, current Git revisions, ready composite resources and both environment responses |

There are now 44 registered labs, including the existing capstones, and 17 playgrounds. Every technical module reading has a module-lab preparation link. Capstone preparation pages link to their integration tasks, and every lab has earlier preparation. The new Workflow reading supplies the Deployment manifest, namespaced permissions and prefilled commands, with a corresponding quiz question. Its `task` input sets the workload message; the resource operation is the literal `create` required by the installed Argo schema.

A preparation link does not mean every command or variation on a page is graded. The generator lab retains the new service for grading; it does not assess folder deletion. The sync-ordering lab checks a successful PreSync operation and wave configuration; its ConfigMap is not consumed by the workload. Existing fault-repair labs cover the separate failure paths. The Flux lab starts without Argo CD and does not assess a live ownership handover between controllers.

The earlier coverage work separated Helm authoring from release-history recovery, added HPA/GitOps ownership checks, and taught the checksum procedure before assessing it. Those exercises remain in place.

The course exercises delivery from Git, packaging, pipelines, progressive delivery and local infrastructure reconciliation. Practical limits remain:

- The image-publishing Task copies an existing image into a local registry. It does not compile application source or prove a reproducible image build.
- Crossplane manages Kubernetes objects inside kind. Provider installation and reconciliation do not establish competence with a real cloud account, credentials or cloud quotas.
- OpenTofu exercises local state and Kubernetes resources. Remote-state locking, cloud backends and concurrent operators are outside these labs.
- Multi-stage release exercises retain their existing duration estimates. Their reference lifecycle proves the requested transitions, not that every command on every reading page was replayed.

## Runtime choice

All current tasks use kind because their assessed behavior belongs to the Kubernetes API, controllers or cluster workloads. Separate environments keep different service meshes and policy configurations independent. Use QEMU for a future task that needs a separate kernel, VM boot behavior or a host service; none of these changes needs it.

## What verification establishes

The workflow checks registration and preparation order, then runs each selected environment on its own runner. A lab first requires API readiness and an explicit grader FAIL, applies its reference solution, runs all configured graders and tears down. The starting-state check stops at the first intentional rejection; it does not prove that every individual criterion fails initially. Shell errors, missing scripts, timeouts and inconsistent verdicts fail the test.

Playgrounds run bootstrap and readiness checks. A playground with testing/smoke.sh also runs that script. A successful playground start alone does not prove all learner commands. Network downloads, public registries and chart repositories remain external dependencies. Consult the test results for actual runtime outcomes; the generated map is not a passing test report.

## Assessment and procedure checks

CI checks quiz registration, answer references, unique question IDs, declared counts and links to earlier readings. Playground procedure tests cover the named examples above; other playgrounds still prove only startup and declared readiness unless they contain their own smoke script. These checks do not establish every command in every lesson.

## Maintaining the map

[LAB-COVERAGE.md](LAB-COVERAGE.md) lists preparation and graded results in both directions. Review individual procedures when changing a reading, even when that reading already has a lab link. Keep fixture limits explicit rather than using a link as evidence of complete skill coverage.

## Reading and practice sequence

Each of the 44 labs has mapped technical preparation after the preceding lab. Ten new capstone readings teach how to connect the module skills before their integration tasks, including the four pairs that previously appeared together. The validator rejects stacked labs even when a question, summary or unrelated reading separates them.

## Validation of this update

On 2026-11-11, all eight added labs passed fresh kind lifecycle tests: bootstrap, readiness, unfinished-state rejection, reference solution and final live grading. The Argo Workflows playground passed its smoke script, including both parameterized Deployment submissions. The directory-generator and promotion-approval labs were rerun successfully after correcting checks for API defaults and aggregated Kubernetes events.

Structure, quiz references, coverage generation and regression checks passed. Existing lab environments outside the eight additions were not rerun for this update. These results establish the tested examples and fixtures, not every procedure in every reading.
