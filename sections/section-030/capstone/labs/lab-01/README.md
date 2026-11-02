---
estimated_duration: 40m
---

# Deliver From Git And Repair A Helm Release With Flux

Graded capstone for the Flux section. The learner gets a `GitRepository` that follows a branch that does not exist, a `scout` `Kustomization` without a dependency, and a `HelmRelease` named `relay` whose last upgrade failed and that has no recovery settings. They repair the delivery from Git, order it with `dependsOn`, deliver a change from Git, repair the Helm release and add upgrade remediation.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-030/capstone/labs/lab-01
astrona submit -c sections/section-030/capstone/labs/lab-01
astrona destroy ats-018-capstone-030
```

Authors can run the reference solution with `astrona test -c sections/section-030/capstone/labs/lab-01`.
