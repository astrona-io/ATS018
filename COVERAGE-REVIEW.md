# Coverage review

The review separates Helm authoring from history-based recovery and adds an HPA/GitOps ownership lab. Its grader commits an unrelated Git change and verifies self-heal while replicas remain under HPA control. The playground exercises the same procedure. The checksum lesson has a linked question, and the release-pipeline task explicitly describes image copying rather than source compilation.

The checksum lab now follows a complete example of step groups, input and output parameters, byte-preserving hashing and inspection of the specific Workflow run. Labs remain beside their preparation, with an explicit mapping for event-driven tasks as well as pipeline definitions.

The course exercises delivery from Git, packaging, pipelines, progressive delivery and local infrastructure reconciliation. Practical limits remain:

- The image-publishing Task copies an existing image into a local registry. It does not compile application source or prove a reproducible image build.
- Crossplane manages Kubernetes objects inside kind. Provider installation and reconciliation do not establish competence with a real cloud account, credentials or cloud quotas.
- OpenTofu exercises local state and Kubernetes resources. Remote-state locking, cloud backends and concurrent operators are outside these labs.
- Multi-stage release exercises retain their existing duration estimates. Their reference lifecycle proves the requested transitions, not that every command on every reading page was replayed.

## Runtime choice

All current tasks use kind because their assessed behavior belongs to the Kubernetes API, controllers or cluster workloads. Separate environments keep different service meshes and policy configurations independent. Use QEMU for a future task that needs a separate kernel, VM boot behavior or a host service; none of these changes needs it.

## What verification establishes

The workflow checks registration and preparation order, then runs each selected environment on its own runner. A lab first requires API readiness and an explicit grader FAIL, applies its reference solution, runs all configured graders and tears down. The starting-state check stops at the first intentional rejection; it does not prove that every individual criterion fails initially. Shell errors, missing scripts, timeouts and inconsistent verdicts fail the test.

Playgrounds run bootstrap and readiness checks. A playground with testing/smoke.sh also runs that script. A successful playground start alone does not prove all learner commands. Network downloads, public registries and chart repositories remain external dependencies. Consult the PR's latest workflow for actual runtime results; this review and the generated map are not passing test reports.

## Assessment and procedure checks

CI checks quiz registration, answer references, unique question IDs, declared counts and links to earlier readings. Playground procedure tests cover the named examples above; other playgrounds still prove only startup and declared readiness unless they contain their own smoke script. These checks do not establish every command in every lesson.

## Readings without a module-lab link

The generated reverse map in [LAB-COVERAGE.md](LAB-COVERAGE.md) lists the current supporting and capstone-only readings. A listed concept is not claimed as independently assessed without a lab link.
