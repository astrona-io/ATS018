---
estimated_duration: 30m
---

# Deliver The Platform With Argo CD And Repair Production

Graded lab for the Crossplane GitOps module. The learner delivers the `platform-infra` repository with an automated Argo CD `Application`, adds a health check for the `ScoutEnvironment` kind, finds why production is not Ready and fixes it in Git.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-090/module-01/labs/lab-01
astrona submit -c sections/section-090/module-01/labs/lab-01
astrona destroy ats-018-lab-090-01
```

Authors can run the reference solution with `astrona test -c sections/section-090/module-01/labs/lab-01`.
