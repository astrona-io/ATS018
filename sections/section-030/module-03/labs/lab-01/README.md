---
estimated_duration: 30m
---

# Fix Broken Argo CD Applications

Graded troubleshooting lab for the Argo CD diagnosis module. Three `Applications` start broken on purpose: a wrong path, a manifest the API server rejects and a missing image tag. The learner reads each failure, fixes it in the right place (Git or the `Application`) and proves the application is `Synced` and `Healthy`.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-030/module-03/labs/lab-01
astrona submit -c sections/section-030/module-03/labs/lab-01
astrona destroy ats-018-lab-030-03
```

Authors can run the reference solution with `astrona test -c sections/section-030/module-03/labs/lab-01`.
