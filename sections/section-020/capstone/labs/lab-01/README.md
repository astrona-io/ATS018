---
estimated_duration: 40m
---

# Deliver Applications With Argo CD End To End

Graded capstone for the Argo CD section. Argo CD and two private repositories exist. One `Application`, `probe`, is already broken: its Git folder names an image tag that does not exist, and it has no automated sync. The learner repairs it in Git, turns on automated sync with prune and self-heal, and creates an `AppProject`, an `ApplicationSet` and a team `Application`.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-020/capstone/labs/lab-01
astrona submit -c sections/section-020/capstone/labs/lab-01
astrona destroy ats-018-capstone-020
```

Authors can run the reference solution with `astrona test -c sections/section-020/capstone/labs/lab-01`.
