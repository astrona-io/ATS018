---
estimated_duration: 50m
---

# Repair A Header-Routed Canary With A Background Analysis

Graded capstone for the progressive delivery section, second lab. The learner gets a `scout` Rollout that uses the Gateway API plugin and does not work: `managedRoutes` is missing, there is no `setCanaryScale` step, the header route matches `Yes` instead of `yes`, and the background analysis measures 5xx responses instead of 2xx. They find each fault from the symptom, fix it, release a good canary and a faulty canary, and end on the good template.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/capstone/labs/lab-02
astrona submit -c sections/section-050/capstone/labs/lab-02
astrona destroy ats-018-capstone-050-02
```

Authors can run the reference solution with `astrona test -c sections/section-050/capstone/labs/lab-02`.
