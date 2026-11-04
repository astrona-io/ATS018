---
estimated_duration: 25m
---

# Reconcile A Git Source With Flux

Graded lab for the Flux Kustomization module. The learner gets a `GitRepository` that follows a branch that does not exist and a `scout` `Kustomization` that has no dependency. They repair the source, add a `platform` `Kustomization`, order the two with `dependsOn` and deliver a change from Git. They also find a third `Kustomization`, `scout-production`, which starts suspended with a drifted live Deployment, and resume it with `flux resume`.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-030/module-01/labs/lab-01
astrona submit -c sections/section-030/module-01/labs/lab-01
astrona destroy ats-018-lab-030-01
```

Authors can run the reference solution with `astrona test -c sections/section-030/module-01/labs/lab-01`.
