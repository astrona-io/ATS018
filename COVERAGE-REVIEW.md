# Coverage review

The checksum lab now follows a complete example of step groups, input and output parameters, byte-preserving hashing and inspection of the specific Workflow run. Labs remain beside their preparation, with an explicit mapping for event-driven tasks as well as pipeline definitions.

The course exercises delivery from Git, packaging, pipelines, progressive delivery and local infrastructure reconciliation. Practical limits remain:

- App-of-apps, Helm as an Argo CD source, permanent drift handling, shared Tekton resolvers and Flux delivery of Crossplane resources have no dedicated module lab.
- The image-publishing Task copies an existing image into a local registry. It does not compile application source or prove a reproducible image build.
- Crossplane manages Kubernetes objects inside kind. Provider installation and reconciliation do not establish competence with a real cloud account, credentials or cloud quotas.
- OpenTofu exercises local state and Kubernetes resources. Remote-state locking, cloud backends and concurrent operators are outside these labs.
- Multi-stage release exercises retain their existing duration estimates. Their reference lifecycle proves the requested transitions, not that every command on every reading page was replayed.

## Runtime choice

All current tasks use kind because their assessed behavior belongs to the Kubernetes API, controllers or cluster workloads. Separate environments keep different service meshes and policy configurations independent. Use QEMU for a future task that needs a separate kernel, VM boot behavior or a host service; none of these changes needs it.

## What verification establishes

The workflow checks registration and preparation order, then runs each selected environment on its own runner. A lab first requires API readiness and an explicit grader FAIL, applies its reference solution, runs all configured graders and tears down. The starting-state check stops at the first intentional rejection; it does not prove that every individual criterion fails initially. Shell errors, missing scripts, timeouts and inconsistent verdicts fail the test.

Playgrounds run bootstrap and readiness checks. A playground with testing/smoke.sh also runs that script. A successful playground start alone does not prove all learner commands. Network downloads, public registries and chart repositories remain external dependencies. Consult the PR's latest workflow for actual runtime results; this review and the generated map are not passing test reports.

## Readings without a module-lab link

These remain visible in the reverse map. Some are supporting concepts or integrated in a section capstone; none is claimed as an independently graded skill merely because it appears in a reading.

- [course-04-helm-charts-as-a-source](sections/section-020/module-01/course-04-helm-charts-as-a-source.md)
- [course-01-app-of-apps](sections/section-020/module-02/course-01-app-of-apps.md)
- [course-03-permanent-drift-and-ignore-differences](sections/section-020/module-03/course-03-permanent-drift-and-ignore-differences.md)
- [course-04-shared-tasks-with-resolvers](sections/section-040/module-01/course-04-shared-tasks-with-resolvers.md)
- [course-06-wait-for-approval-before-promotion](sections/section-050/module-03/course-06-wait-for-approval-before-promotion.md)
- [course-05-deliver-the-platform-with-flux](sections/section-060/module-01/course-05-deliver-the-platform-with-flux.md)
