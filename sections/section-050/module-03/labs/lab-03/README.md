---
estimated_duration: 20m
---

# Require Manual Approval Before A Flagger Rollout

Add a confirmation webhook to an existing Canary, preserve its events while
it waits, and open the gate to promote podinfo 6.15.0. This short task reuses
the mesh-free bootstrap from lab-02 with an initialized ungated Canary.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/labs/lab-03
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/labs/lab-03
astrona destroy ats-018-lab-050-03-03
```

Author checks are offline only. No cluster was booted for this addition.
