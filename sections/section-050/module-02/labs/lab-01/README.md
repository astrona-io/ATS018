---
estimated_duration: 30m
---

# Hand Off A Release From Tekton To Argo CD

Graded lab for the Tekton hand-off module. The learner gets three finished Tasks, a private Git repository and an Argo CD `Application`, but no Pipeline and no Git credentials. They give a service account Git credentials, chain the Tasks in a Pipeline, run it and prove that Argo CD serves the new version.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-02/labs/lab-01
astrona submit -c sections/section-050/module-02/labs/lab-01
astrona destroy ats-018-lab-050-02
```

Authors can run the reference solution with `astrona test -c sections/section-050/module-02/labs/lab-01`.
