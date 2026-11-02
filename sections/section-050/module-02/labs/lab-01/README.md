---
estimated_duration: 35m
---

# Gate A Blue/Green Release With Analysis

Graded lab for the blue/green analysis module. The learner adds a Prometheus pre-promotion gate to the `scout` Rollout, releases a good and a faulty candidate, and ends on the good template.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-02/labs/lab-01
astrona submit -c sections/section-050/module-02/labs/lab-01
astrona destroy ats-018-lab-050-02
```

Authors can run the reference solution with `astrona test -c sections/section-050/module-02/labs/lab-01`.
