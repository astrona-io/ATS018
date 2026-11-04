---
estimated_duration: 25m
---

# Gate A Canary With A Web Analysis Step

Graded lab for the Argo Rollouts canary module. The learner starts from a Rollout paused at a canary step, finishes that release with `promote` and `promote --full`, completes a `web` AnalysisTemplate, replaces a `pause` step with an inline `analysis` step, triggers a release with an environment variable and reads the AnalysisRun.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/labs/lab-02
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/labs/lab-02
astrona destroy ats-018-lab-050-01-02
```

Author checks for this addition are offline only. No cluster was booted.
