---
estimated_duration: 25m
---

# Deliver An Application From Git With Argo CD

Graded lab for the Argo CD module. The cluster has Argo CD and a private Git repository for `scout`, but no `Application` and no repository credentials. The learner connects the repository, creates an `Application` with automated sync, prune and self-heal, and proves that Argo CD delivers `scout` and reverts manual changes.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-020/module-01/labs/lab-01
astrona submit -c sections/section-020/module-01/labs/lab-01
astrona destroy ats-018-lab-020-01
```

Authors can run the reference solution with `astrona test -c sections/section-020/module-01/labs/lab-01`.
