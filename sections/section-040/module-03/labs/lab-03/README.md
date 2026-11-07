---
estimated_duration: 20m
---

# Insert A Step Between Two Existing Steps

Graded lab for the Argo Workflows module. The learner reads a WorkflowTemplate with the `argo` command-line tool, adds a template that hashes an input parameter and exports the digest, inserts a step for it between two existing steps of a `steps` list so that it runs after the first and before the second, runs the changed template with `argo submit`, reads the result with `argo get` and `argo logs`, and deletes the run from before the change.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
astrona destroy ats-018-lab-040-03-03
```

Bootstrap installs the `argo` command-line tool v4.1.6 in `~/.astrona/bin` when no `argo` is on the `PATH`. It keeps an existing `argo` of any version and prints a warning when that version differs.

Author checks for this addition are offline only. No cluster was booted.
