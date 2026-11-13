---
estimated_duration: 25m
---

# Release A New Version With A Canary Rollout

Graded lab for the Argo Rollouts canary module. The learner converts the `scout` Deployment into a canary Rollout and releases podinfo 6.15.0 through its pause steps.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-070/module-01/labs/lab-01
astrona submit -c sections/section-070/module-01/labs/lab-01
astrona destroy ats-018-lab-070-01
```

Authors can run the reference solution with `astrona test -c sections/section-070/module-01/labs/lab-01`.
