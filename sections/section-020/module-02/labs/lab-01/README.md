---
estimated_duration: 30m
---

# Generate Applications And Restrict A Team With An AppProject

Graded lab for the ApplicationSet module. Argo CD and two private repositories exist, but no `Application`, `ApplicationSet` or extra `AppProject`. The learner creates an `AppProject` for the `outpost` team, an `ApplicationSet` that generates one `Application` per environment, and an `Application` for the `outpost` team that runs inside its project.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-020/module-02/labs/lab-01
astrona submit -c sections/section-020/module-02/labs/lab-01
astrona destroy ats-018-lab-020-02
```

Authors can run the reference solution with `astrona test -c sections/section-020/module-02/labs/lab-01`.
