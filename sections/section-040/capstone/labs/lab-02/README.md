---
estimated_duration: 40m
---

# Repair A Push-Driven Argo Events And Workflows Pipeline

Graded capstone for the continuous integration section, second lab. The learner gets a pipeline that is wired end to end and does not work: the Sensor filters the wrong branch and passes the wrong commit field, the WorkflowTemplate starts in a folder that does not exist, and the service account of the workflow pods has a Role but no RoleBinding for `workflowtaskresults`. They find each fault from the symptom, fix it, push a commit and prove that a Workflow for exactly that commit Succeeded.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/capstone/labs/lab-02
astrona submit -c sections/section-040/capstone/labs/lab-02
astrona destroy ats-018-capstone-040-02
```

Authors can run the reference solution with `astrona test -c sections/section-040/capstone/labs/lab-02`.
