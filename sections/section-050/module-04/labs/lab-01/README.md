---
estimated_duration: 40m
---

# Route And Guard A Canary Through The Gateway API

Graded lab for the Argo Rollouts traffic-router module. The learner adds a header test route and a background analysis to the `scout` Rollout, releases a good and a faulty canary, and ends on the good template.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-04/labs/lab-01
astrona submit -c sections/section-050/module-04/labs/lab-01
astrona destroy ats-018-lab-050-04
```

Authors can run the reference solution with `astrona test -c sections/section-050/module-04/labs/lab-01`.
