---
estimated_duration: 25m
---

# Run A Pipeline That Changes The Cluster With tkn

Graded lab for the Tekton Tasks and Pipelines module. The learner starts from a failed PipelineRun, reads the failure with `tkn`, adds a Task that runs in parallel with another, extends a ClusterRole, starts the Pipeline twice with `tkn pipeline start` and different `-p` values and the right ServiceAccount, saves the log of one run to a file, and deletes the failed run.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-01/labs/lab-02
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-01/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-01/labs/lab-02
astrona destroy ats-018-lab-040-01-02
```

Bootstrap installs the `tkn` command-line tool 0.46.1 in `~/.astrona/bin` when no `tkn` is on the `PATH`. It keeps an existing `tkn` of any version and prints a warning when that version differs.

Author checks for this addition are offline only. No cluster was booted.
