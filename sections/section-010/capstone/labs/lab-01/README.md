---
estimated_duration: 30m
---

# Packaging Applications For GitOps Capstone

Graded capstone for section 010. The learner gets a `scout` Kustomize tree with four faults: a wrong file name in the base, an image entry that matches nothing, a `replicas` entry for a Deployment that does not exist, and a generated ConfigMap whose name does not match the name the patch uses. The learner fixes the tree and applies the `staging` and `production` overlays.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/capstone/labs/lab-01
astrona submit -c sections/section-010/capstone/labs/lab-01
astrona destroy ats-018-capstone-010
```

Authors can run the reference solution with `astrona test -c sections/section-010/capstone/labs/lab-01`.
