---
estimated_duration: 20m
---
# OpenTofu Playground

An ungraded environment for inspecting state, reviewing plans and adding a Service.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-02/playground

astrona destroy ats-018-playground-060-02
```

Bootstrap installs OpenTofu 1.13.2 in `~/.astrona/bin`, downloads provider 3.4.0
with `tofu init`, and applies starter resources to generate real local state.
It requires outbound HTTPS to the OpenTofu registry, GitHub releases and the
provider download hosts. It fails early if download or initialization fails.
Python 3 and curl are terminal prerequisites. Only podinfo and the request client
run in the cluster. No cloud account or infrastructure controller is needed.

Author status: built without booting on 2026-11-04. Runtime behaviour remains untested.
