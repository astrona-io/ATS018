# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.

## About this repo (ATS018 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** pass the **GitOps and Continuous Delivery** domain of the
  **Certified Cloud Native Platform Engineer (CNPE)** exam. It is 25% of the
  exam.
- **What the exam really tests:** 15 to 20 hands-on tasks in 2 hours, done
  over `ssh <node>` on Kubernetes 1.35 with `kubectl`, `yq` and `curl`. The
  exam spans many tools and goes shallow on each: the only documentation
  allowed is kubernetes.io/docs, the Kubernetes blog and a per-task "Quick
  Reference" for the tool in that task. Some tasks let the candidate pick a
  tool (Argo CD or Flux, Argo Rollouts or Flagger). So for each tool the
  student must *do* the one job the exam asks: write the object, read its
  status with the tool's command-line tool and `kubectl`, and fix it when it
  fails. Every explanation should lead to a command they can run, and every
  result should be proved on the live cluster (a synced and healthy
  Application, a request from `shuttle` that returns the new version, an
  aborted rollout that keeps the old version serving).
- **The three exam competencies (curriculum items):**
  - Implementing GitOps Workflows for Application and Infrastructure Deployment
  - Building and Configuring CI/CD Pipelines Integrated with Kubernetes
  - Deploying Applications Using Progressive Delivery Strategies (for example
    Blue/Green or Canary)
- **Tool pairs:** where the exam lets the candidate choose, both tools are
  taught. The primary tool gets full depth (Argo CD, Argo Rollouts), the
  secondary gets a compact treatment (Flux, Flagger) that maps each object
  back to the primary tool.
- **Only official CNPE tools are taught.** The exam lists Argo (CD,
  Rollouts, Workflows, Events), Crossplane, Flagger, Flux, Gatekeeper,
  Grafana, Istio, Jaeger, Kyverno, Linkerd, OPA, OpenCost, OpenTelemetry,
  Prometheus and Tekton, plus built-in Kubernetes (`kubectl`, the Kustomize
  inside `kubectl`, the core APIs). Anything else is a waste of the
  student's time and is never a lesson subject. Helm charts appear only as
  something a listed tool consumes (a Flux `HelmRelease`, an Argo CD
  Application with a Helm source); the `helm` command-line tool is never
  taught. Gitea, the in-cluster registry, `crane` and Helm itself are
  plumbing: playground bootstraps install and seed them, and a lesson names
  them in one sentence at most and never teaches their web UI or CLI.
- **The sections:** the order follows a change from Git to users: package
  it, deliver it, produce a new version, release it safely.

  | Section | Title | Curriculum item |
  | --- | --- | --- |
  | 010 | Packaging Applications For GitOps (Kustomize only) | Implementing GitOps Workflows |
  | 020 | Continuous Delivery With Argo CD | Implementing GitOps Workflows |
  | 030 | Continuous Delivery With Flux | Implementing GitOps Workflows |
  | 040 | Continuous Integration Pipelines With Tekton | Building and Configuring CI/CD Pipelines |
  | 050 | Progressive Delivery | Deploying Applications Using Progressive Delivery Strategies |

  The full design (modules, objectives, playground environments, capstones)
  is in `.astrona/blueprint.yaml`.

- **The versions:** everything is built and checked on a `kind` v0.33.0
  cluster with node image `kindest/node:v1.35.8` (Kubernetes 1.35, the exam
  version). Pinned tools:

  | Tool | Version |
  | --- | --- |
  | Kustomize (inside `kubectl` 1.35) | 5.7.1 (the only Kustomize the lessons use) |
  | Helm (bootstrap plumbing only, not taught) | 4.3.0 |
  | Argo CD | 3.5.4 |
  | Flux | 2.9.6 |
  | Tekton Pipelines / Triggers / `tkn` | 1.17.0 / 0.36.4 / 0.46.1 |
  | Argo Rollouts | 1.10.0 |
  | Flagger | 1.45.0 |
  | Istio (Flagger module only) | 1.31.1 |
  | kube-prometheus-stack chart | 92.3.0 |
  | Gitea (plumbing only, not taught) | `gitea/gitea:28.1.0-rootless` |
  | podinfo / go-httpbin | 6.15.0 / 2.25.0 |

  Do not teach fields, flags or output from other versions without saying so.
- **The main sources:** the official documentation of each tool (listed
  under "Where to find trusted sources") and the Linux Foundation CNPE pages.
  Check every page against them.

### Terms, not metaphors

Explanations use Kubernetes' and each tool's own words. Define each one in
plain technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| GitOps | A way to run a cluster where a Git repository holds the desired state and a controller in the cluster keeps the live state equal to it |
| Desired state / live state | What the files in Git say the cluster should run / what the cluster runs right now |
| Reconciliation | The loop where a controller compares the desired state with the live state and changes the cluster to remove the difference |
| Drift | A difference between the live state and Git, for example after a manual `kubectl edit` |
| Kustomize base / overlay | A folder of shared manifests / a folder that changes the base for one environment with patches |
| Helm chart / release / revision | A package of templates and default values / one installed copy of a chart / one numbered version of a release |
| Argo CD `Application` | The Argo CD object that says which Git path to render and which cluster and namespace to sync it to |
| Sync status / health status | Whether the live objects match Git (`Synced`, `OutOfSync`) / whether they work (`Healthy`, `Progressing`, `Degraded`, `Missing`, `Suspended`) |
| `ApplicationSet` | An Argo CD object that generates many `Application` objects from a template and a generator |
| `AppProject` | An Argo CD object that limits which repositories and destinations a group of Applications may use |
| Flux `GitRepository` / `Kustomization` / `HelmRelease` | The Flux source that fetches a Git path / the object that applies it / the object that installs a Helm chart |
| Tekton `Task` / `Pipeline` | A list of steps that run as containers in one pod / an ordered graph of Tasks |
| `TaskRun` / `PipelineRun` | One run of a Task / of a Pipeline, with its parameters and status |
| Workspace | A volume that Tekton mounts into the steps of a Task so they can share files |
| `EventListener` | The Tekton Triggers object that receives a webhook and creates a run from it |
| Argo Rollouts `Rollout` | A replacement for a Deployment that adds canary and blue/green strategies |
| `AnalysisTemplate` / `AnalysisRun` | A metric query with success and failure conditions / one evaluation of it during a rollout |
| Flagger `Canary` | A Flagger object that takes over a Deployment, creates primary and canary copies and shifts traffic based on metrics |
| Canary / blue/green | A new version that gets a growing share of traffic / two full versions with traffic switched in one step |

Do not use space metaphors for these concepts ("mission control" for Argo
CD, "launch sequence" for a pipeline). Use the real terms.

### The example workloads

The Starfleet names from the general rules are the example workloads. Each
module's playground deploys only the ones it needs. Describe them in
technical terms and use the names as they are.

| Kubernetes name | Image | What it is |
| --- | --- | --- |
| `scout` | `ghcr.io/stefanprodan/podinfo:6.15.0` | Web application on port `9898`; the response shows its version; exposes Prometheus metrics on `/metrics`. An older 6.14.x tag is the "previous version" in rollout modules |
| `probe` | `mccutchen/go-httpbin:2.25.0` | HTTP echo server on port `8080`, used where a second service is needed |
| `shuttle` | `curlimages/curl` | Client pod; every test request is sent with `kubectl exec deploy/shuttle -- curl ...` |
| `bridge` | `nginx` | Front end, only in a module that needs one |

Namespaces: `starfleet` for the main team and `outpost` for a second tenant.
Where a module needs one namespace per environment, use `starfleet-staging`
and `starfleet-production`.

**Gitea** (plumbing, never taught) runs in namespace `gitea` with the in-cluster URL
`http://gitea-http.gitea.svc:3000`, admin user `platform` and organisation
`starfleet`. Playgrounds seed the repositories they need, named after their
content: `starfleet/scout-deploy` (Kustomize base and overlays, Helm values),
`starfleet/scout-app` (source for the CI pipeline), `starfleet/platform-apps`
(one directory per application for ApplicationSets).

### Environment facts the text must respect

- **Pin the cluster in `config.yaml`.** astrona's kind runtime takes
  `runtime.kind.image: kindest/node:v1.35.8` (or `runtime.kind.version`),
  `runtime.kind.nodes.workers`, `featureGates`, `runtimeConfig`,
  `preloadImages` and addons (`metricsServer`, `certManager`,
  `gatewayAPI: envoy`, `cni: calico`); see `astrona schema`. Prefer an addon
  over a hand-written install when it fits. It does not expose
  `kubeadmConfigPatches` or `extraMounts`.

- **One tool stack per playground.** The maintainer runs Podman with 10 GiB
  of memory that also runs the platform stack. Each playground installs only
  what its module needs; the heaviest ones (Argo CD plus Tekton plus Gitea,
  Istio plus Flagger plus Prometheus) must be checked against that budget.
- **Gitea runs small.** Its Helm chart can pull in database and cache
  clusters by default; playgrounds run Gitea with its built-in SQLite
  database and no extra cache cluster. Verify the chart values at build.
- **No load balancer on `kind`.** A Service of type `LoadBalancer` keeps
  `EXTERNAL-IP` as `<pending>`. Pages reach the Argo CD and Gitea web pages
  with `kubectl port-forward`.
- **Many environments start broken on purpose.** A playground or lab often
  seeds a broken Application, overlay, HelmRelease or pipeline. The fault is
  the material. Never "fix" it in the bootstrap.
- **The fix goes in Git.** In a GitOps environment, a page never fixes a
  delivered object with `kubectl edit`; with self-heal on, the controller
  reverts it. Change the repository and let the controller sync.
- **The CI "build" is a copy.** To stay within the memory budget, the
  pipeline publishes a new image tag by copying the podinfo image inside the
  in-cluster registry instead of building it. Say so in the text.
- **Facts to verify at build, not from memory:**
  - Argo CD 3.x defaults that changed from 2.x (resource tracking method,
    RBAC inheritance, default resource exclusions). Check the 2.14 to 3.0
    upgrade notes.
  - The name and location of the initial admin password Secret in Argo CD
    3.5.
  - Tekton resolvers (verified 2026-10-10): Pipelines 1.17 enables all five
    resolvers (`cluster`, `git`, `bundles`, `http`, `hub`) in the ConfigMap
    `resolvers-feature-flags`. The hub resolver defaults to `type: artifact`
    (Artifact Hub); Tekton Hub is shut down (`api.hub.tekton.dev` no longer
    resolves). The git resolver's `url` form clones anonymously unless the
    `gitToken` param names a token Secret. Do not preload the digest-pinned
    Tekton images: kind then fails the pods with `CreateContainerError`.
  - Helm 4.3.0 (bootstrap only, checked 2026-10-10): `--wait` defaults to
    `hookOnly` when omitted, `--atomic` is now `--rollback-on-failure`, and
    new installs use server-side apply by default.
  - podinfo's metric names, labels and its option for returning random
    errors, before writing PromQL or an `AnalysisTemplate`.
  - podinfo chart 6.15.0 readiness (verified 2026-10-10): its probe path
    is fixed at `/readyz`; a `readinessProbe.httpGet.path` value has no
    effect. Use `faults.unready: true` for the deliberate Flux upgrade
    failure, then `false` to repair it. The failed upgrade leaves the
    previous successful revision in release history as `deployed`.
  - Which Flagger provider settings and bundled Prometheus the Istio
    install of Flagger 1.45 uses.
  - The `kubectl` embedded Kustomize version on Kubernetes 1.35.
  Never copy command output from memory or from an older page.
- **The proof is behaviour.** A result is proven with a request from
  `shuttle` that returns the expected version, plus the matching status
  command (`argocd app get` `Synced` and `Healthy`, `flux get` `Ready`,
  `tkn pipelinerun describe` `Succeeded`, `kubectl argo rollouts get rollout`
  `Healthy`).

### Where things are in this repo

| What | Where |
| --- | --- |
| Course design: sections, modules, objectives, playground environments | `.astrona/blueprint.yaml` |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The exam-style task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough with real output |
| `bootstrap/` | Numbered scripts that install the tools (`01-install-<tool>.sh`), seed Gitea and create the starting state |
| `manifests/` | The starting workloads and the broken or incomplete objects the learner must fix |
| `solution/apply.sh`, `solution/` files | Reference end state, applied only by `astrona test` |
| `testing/` | Helpers `astrona test` runs (for example waiting for a controller to be ready) |
| `validation/validate-*.sh` | Behavioural grading, one script per check (for example `validate-app-synced.sh`, `validate-new-version-served.sh`) |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS018`, domain
`GitOps and Continuous Delivery`, weight `25`) and one entry per section
under `modules:` (`module-intro`, then `module-010`, `module-020` and so on).
Each section's `content` lists, in order: the section `README.md`, then for
each module its landing page, its parts, and right after the part a lab
tests, a `Question` reading (`labs/lab-01/question.md`) followed by the
`type: lab` entry; the module's closing page comes last. The section
capstone closes the section. Playgrounds are not listed: the landing page's
`<!-- astrona:playground -->` marker shows them.

Every `type: lab` entry (module labs and capstones) carries these fields, in
this order:

```yaml
      - type: reading
        title: Question
        path: sections/section-020/module-01/labs/lab-01/question.md
      - type: lab
        title: "Deliver An Application From Git With Argo CD Lab"
        path: sections/section-020/module-01/labs/lab-01
        difficulty: beginner
        estimated_duration: 20m
        topic: argocd
        task_kind: build
        tags: [argocd-application, sync-policy, self-heal, prune, gitea]
        learning_goals:
          - Create an Application that syncs a Kustomize overlay from Gitea into its namespace
          - Turn on automated sync with prune and self-heal
          - Prove a manual change is reverted and the new version answers from shuttle
        resources:
          - name: "Argo CD declarative setup"
            url: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
```

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`, `45m`.
- `topic`: exactly one of `packaging`, `argocd`, `flux`, `ci-pipelines`,
  `gitops-handoff`, `progressive-delivery`.
- `task_kind`: exactly one of `build` (write the configuration from
  scratch), `troubleshooting` (find and fix what is broken) or `migration`
  (move a working setup to another tool or layout). The platform filters
  labs by it, so it is a field of its own, never a tag.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb, saying
  what the learner proves in this lab.
- `resources`: 1 to 4 documentation pages, each with a `name` and a `url`
  that loads. This is the **only** place outside links are allowed: the
  platform shows them as optional further reading next to the lab.

**Tag list** (lower case, hyphens, never synonyms):

- Packaging: `kustomize`, `overlays`, `patches`, `config-generator`
- Argo CD: `argocd-application`, `sync-policy`, `self-heal`, `prune`,
  `sync-waves`, `sync-hooks`, `ignore-differences`, `applicationset`,
  `app-of-apps`, `appproject`, `repository-credentials`, `out-of-sync`,
  `health-status`
- Flux: `flux-gitrepository`, `flux-kustomization`, `helmrelease`,
  `helmrelease-remediation`, `depends-on`, `reconcile`
- Tekton: `tekton-task`, `tekton-pipeline`, `workspaces`, `params-results`,
  `resolvers`, `tekton-triggers`, `eventlistener`, `webhook`
- Hand-off: `image-tag-update`, `git-credentials`, `container-registry`
- Progressive delivery: `argo-rollouts`, `canary`, `blue-green`,
  `analysistemplate`, `promotion`, `abort-rollback`, `flagger`, `istio`,
  `prometheus`, `promql`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-01/playground
astrona destroy ats-018-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-020/module-01/labs/lab-01
astrona submit -c sections/section-020/module-01/labs/lab-01
astrona destroy ats-018-lab-020-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-020/module-01/labs/lab-01
```

Names: a playground is `ats-018-playground-<section>-<module>`, a module lab
is `ats-018-lab-<section>-<module>` and a capstone is
`ats-018-capstone-<section>`; keep those names. A second lab in a module
takes `ats-018-lab-<section>-<module>-<lab>`, for example
`ats-018-lab-020-02-02`, so two labs never share a name. Lab bootstrap
scripts do not pin a kube context: astrona sets `KUBECONFIG` for the lab, and
`astrona test` runs on a cluster with a different name. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists: send a real
request from `shuttle` and check the version it returns, read the
controller's own status (`Synced`/`Healthy`, `Ready`, `Succeeded`), and
check Git when the task asks for a change in Git. Many graders also reject
the plausible but wrong fix (editing the live object instead of Git,
turning off self-heal or prune to hide drift, deleting a failing analysis
instead of fixing the release). A lab's `question.md` and `solution.md`
must match what its `validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Podman has 10 GiB
and also runs the platform stack; parallel clusters run it out of memory.
Never touch clusters you did not create.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **The exam itself:**
  [CNPE certification page](https://training.linuxfoundation.org/certification/certified-cloud-native-platform-engineer-cnpe/),
  [Important Instructions: CNPE](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cnpe),
  [Resources allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)
- **Packaging:**
  [Kustomize in kubectl](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/),
  [Kustomize reference](https://kubectl.docs.kubernetes.io/references/kustomize/)
- **Argo CD:**
  [documentation](https://argo-cd.readthedocs.io/en/stable/),
  [declarative setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/),
  [automated sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/),
  [sync waves and hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/),
  [ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/),
  [upgrade notes](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/)
- **Flux:**
  [documentation](https://fluxcd.io/flux/),
  [GitRepository](https://fluxcd.io/flux/components/source/gitrepositories/),
  [Kustomization](https://fluxcd.io/flux/components/kustomize/kustomizations/),
  [HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/)
- **Tekton:**
  [Pipelines documentation](https://tekton.dev/docs/pipelines/),
  [Triggers documentation](https://tekton.dev/docs/triggers/),
  [tkn CLI](https://tekton.dev/docs/cli/)
- **Progressive delivery:**
  [Argo Rollouts documentation](https://argo-rollouts.readthedocs.io/en/stable/),
  [Argo Rollouts analysis](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/),
  [Flagger documentation](https://docs.flagger.app/)
- **Example app:**
  [podinfo](https://github.com/stefanprodan/podinfo),
  [Gitea documentation](https://docs.gitea.com/)

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository: planning
(`domain-plan`), creating the tree (`domain-scaffold`), building modules
(`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds (`lab`),
lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
