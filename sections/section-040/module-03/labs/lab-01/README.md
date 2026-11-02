---
estimated_duration: 30m
---

# Start A Workflow From A Git Push With Argo Events

Graded lab for the Argo Workflows module. The learner gets a WorkflowTemplate that starts in a folder that does not exist, a Gitea webhook that nothing answers and a ready EventBus. They fix the template, create the EventSource and the Sensor, push a commit and prove that the push started a Succeeded Workflow.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-01
astrona submit -c sections/section-040/module-03/labs/lab-01
astrona destroy ats-018-lab-040-03
```

Authors can run the reference solution with `astrona test -c sections/section-040/module-03/labs/lab-01`.
