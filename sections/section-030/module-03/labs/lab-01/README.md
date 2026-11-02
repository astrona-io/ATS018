---
estimated_duration: 30m
---

# Automate Image Updates With Flux

Graded lab for the Flux image automation module. Flux delivers `scout` 6.14.0 from Git and the in-cluster registry also holds 6.15.0. The learner creates an `ImageRepository`, an `ImagePolicy` and an `ImageUpdateAutomation` so that Flux itself commits the newest tag to Git and delivers it.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-030/module-03/labs/lab-01
astrona submit -c sections/section-030/module-03/labs/lab-01
astrona destroy ats-018-lab-030-03
```

Authors can run the reference solution with `astrona test -c sections/section-030/module-03/labs/lab-01`.
