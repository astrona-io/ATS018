---
estimated_duration: 25m
---

# Run And Repair Workflows With The argo Command-Line Tool

Graded lab for the Argo Workflows module. The learner starts from a failed run, reads the failure with `argo list`, `argo get` and `argo logs`, fixes the WorkflowTemplate, runs a copied step in parallel in a `steps` list, submits a second template with a namespace parameter and a ServiceAccount, and deletes every run except one success per template.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-01/labs/lab-02
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-01/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-01/labs/lab-02
astrona destroy ats-018-lab-060-01-02
```

Bootstrap installs the `argo` command-line tool v4.1.6 in `~/.astrona/bin` when no `argo` is on the `PATH`. It keeps an existing `argo` of any version and prints a warning when that version differs.

Author checks for this addition are offline only. No cluster was booted.
