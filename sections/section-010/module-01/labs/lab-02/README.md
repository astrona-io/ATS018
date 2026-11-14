---
estimated_duration: 20m
---

# Build A Kustomize Overlay With A Generated ConfigMap

Graded build lab for the Kustomize module. The learner completes an empty staging overlay: namespace, image tag, replica count, a `configMapGenerator` and a patch that adds `envFrom`. The lab then checks the live workload, `kubectl diff -k` and a request from `shuttle`.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-01/labs/lab-02
astrona submit -c sections/section-010/module-01/labs/lab-02
astrona destroy ats-018-lab-010-01-02
```

Authors can run the reference solution with `astrona test -c sections/section-010/module-01/labs/lab-02`.

Built without booting on 2026-11-04 as the Kustomize half of a former packaging capstone. Structural validation and offline rendering do not establish runtime correctness.
