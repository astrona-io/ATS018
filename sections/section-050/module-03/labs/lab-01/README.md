---
estimated_duration: 40m
---

# Release And Roll Back A Canary With Flagger

Graded lab for the Flagger module. The learner creates a `Canary` for `scout`, promotes 6.15.0, sees a faulty release roll back and promotes a fixed template.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/labs/lab-01
astrona submit -c sections/section-050/module-03/labs/lab-01
astrona destroy ats-018-lab-050-03
```

Authors can run the reference solution with `astrona test -c sections/section-050/module-03/labs/lab-01`.
