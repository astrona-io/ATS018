---
estimated_duration: 40m
---

# Continuous Integration Pipelines Capstone

Graded capstone for the continuous integration section. The learner gets a release Pipeline that fails for four separate reasons: `publish-image` gets no `version` parameter and does not wait for the tests, the `run-tests` Task starts in a directory that does not exist, the service account has no Git credentials, and a run needs a workspace that keeps its files between Tasks. They repair each cause, run the Pipeline and prove that Argo CD serves the new version from the commit that the pipeline pushed.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/capstone/labs/lab-01
astrona submit -c sections/section-040/capstone/labs/lab-01
astrona destroy ats-018-capstone-040
```

Authors can run the reference solution with `astrona test -c sections/section-040/capstone/labs/lab-01`.
