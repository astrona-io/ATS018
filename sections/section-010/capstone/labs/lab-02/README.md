---
estimated_duration: 35m
---

# Deploy With Helm And A Kustomize Overlay

Graded packaging capstone. Complete a Helm chart for production and a Kustomize overlay for staging, then prove the two workload configurations.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/capstone/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/capstone/labs/lab-02
astrona destroy ats-018-capstone-010-02
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, preloaded images and script wiring |
| `bootstrap/` | Install Helm 4.3.0 and seed the starting environment |
| `manifests/` | Namespaces and the shuttle client |
| `resources/` | Starter files copied to `~/resources` in the terminal |
| `question.md` | Graded task |
| `solution.md` | Guided solution with feedback steps |
| `solution/` | Reference files and `apply.sh` |
| `validation/` | Source, live state and response checks |

Built without booting on 2026-11-04. Structural validation and offline rendering do not establish runtime correctness.
