---
estimated_duration: 20m
---

# Repair A Failing HelmRelease And Add Remediation

Graded lab for the HelmRelease module. The learner gets a `scout` `HelmRelease` whose last upgrade failed because the pods never become ready. They repair the values of the existing release and configure rollback remediation for future failed upgrades.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-030/module-02/labs/lab-01
astrona submit -c sections/section-030/module-02/labs/lab-01
astrona destroy ats-018-lab-030-02
```

Authors can run the reference solution with `astrona test -c sections/section-030/module-02/labs/lab-01`.
