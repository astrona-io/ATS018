---
estimated_duration: 20m
---

# Gate A Mesh-Free Blue/Green Release With Flagger

Release a new environment value with Flagger's Kubernetes provider. Observe a failed HTTP gate, repair it, and save live Canary events. This environment installs Flagger 1.45.0 and load tester 0.39.0 without Istio or Prometheus.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/labs/lab-02
astrona destroy ats-018-lab-050-03-02
```

Author checks for this addition are offline only. No cluster was booted.
