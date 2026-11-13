---
estimated_duration: 20m
---

# Fix A Failing Tekton Pipeline

Graded lab for the Tekton Tasks and Pipelines module. The learner gets a Pipeline whose `run-tests` Task starts in a directory that does not exist. They start a `PipelineRun`, read the failure down to the step log, fix the Task and get a `Succeeded` run.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/labs/lab-01
astrona submit -c sections/section-050/module-01/labs/lab-01
astrona destroy ats-018-lab-050-01
```

Authors can run the reference solution with `astrona test -c sections/section-050/module-01/labs/lab-01`.
