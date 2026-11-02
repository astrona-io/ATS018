---
estimated_duration: 25m
---

# Fix And Deploy Kustomize Overlays

Graded lab for the Kustomize module. The learner gets a `scout` Kustomize tree with three faults, fixes it and applies the `staging` and `production` overlays.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-018-lab-010-01
```

Authors can run the reference solution with `astrona test -c sections/section-010/module-01/labs/lab-01`.
