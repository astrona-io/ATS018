---
estimated_duration: 40m
---

# Progressive Delivery Capstone

Graded capstone for the progressive delivery section. The learner repairs the background analysis of a canary `Rollout` (the argument judges the stable template, and the query uses the wrong `path` label), releases a faulty candidate that the gate aborts, then promotes a good candidate. Only the Argo Rollouts and Prometheus stack is used, to stay within the memory budget; Flagger and Istio are not part of this lab.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/capstone/labs/lab-01
astrona submit -c sections/section-050/capstone/labs/lab-01
astrona destroy ats-018-capstone-050
```

Authors can run the reference solution with `astrona test -c sections/section-050/capstone/labs/lab-01`.
