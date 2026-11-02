---
estimated_duration: 45m
---

# Infrastructure Deployment Through GitOps Capstone

Graded capstone for the Crossplane GitOps section. The learner delivers the `platform-infra` repository with an automated Argo CD `Application`, adds a health check for the `ScoutEnvironment` kind and fixes two faults in Git: the `preview` environment has `replicas: "1"` (a string, so the API server rejects it) and the `Composition` points the Service at the target port `web` instead of the container port `http` (the environments are `Ready` but no request reaches the pods).

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/capstone/labs/lab-01
astrona submit -c sections/section-060/capstone/labs/lab-01
astrona destroy ats-018-capstone-060
```

Authors can run the reference solution with `astrona test -c sections/section-060/capstone/labs/lab-01`.
