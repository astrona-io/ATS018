---
estimated_duration: 20m
---

# Create PipelineRuns From JSON Requests With Tekton Triggers

Graded lab for Tekton Triggers. A learner extracts two values from a JavaScript Object Notation (JSON) request, substitutes them into a PipelineRun, connects an existing EventListener and repairs its role-based access control (RBAC) permissions. An EventListener is the Tekton Triggers resource that receives requests and creates resources from a template. A PipelineRun is one execution of a Tekton Pipeline.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-02/labs/lab-02
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-02/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-02/labs/lab-02
astrona destroy ats-018-lab-040-02-02
```

Bootstrap installs Tekton Pipelines 1.17.0 and Triggers 0.36.4 without interceptors. It installs the `tkn` command-line tool 0.46.1 in `~/.astrona/bin` if no `tkn` is on `PATH`. The node preloads the step and client images; the controller images, including the EventListener sink image, are pulled from the pinned releases during bootstrap.

The existing Pipeline `scout-check` checks that both params are nonempty. It does not clone a repository or publish an image. This keeps the task focused on request-to-run parameter delivery. The listener account can read Triggers resources but cannot create runs; its cluster-scoped read permissions already exist.

The grader sends two unique payloads from `shuttle`, correlates the event IDs with new runs, and checks both the PipelineRun and its TaskRun. It removes only the runs created by those grading requests. A separate check keeps the learner's successful main-branch request as evidence. The template check also compares the existing Pipeline with the admitted specification saved by bootstrap, so changing the supplied Pipeline cannot hide a parameter-delivery error.

Author checks for this addition are static only. YAML parsing and `bash -n` passed. `astrona validate` could not open the home-directory `.maintenance.lock` under the authoring sandbox. No cluster was booted.
