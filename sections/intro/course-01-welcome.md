# Welcome To The Course

This course trains you for the **GitOps and Continuous Delivery** part of the **Certified Cloud Native Platform Engineer (CNPE)** exam. That part is 25% of the exam. This page tells you who the course is for, what you can do at the end, which words and example app it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, ConfigMaps, Secrets, pod labels, `kubectl logs` and `kubectl exec`. You can read and write YAML, and you have used `git` to commit and push a change. You do not need to know Argo CD, Flux, Tekton or Argo Rollouts. Each new idea is explained the first time it appears.

## What you can do at the end

The exam is hands-on. You get a set of Kubernetes clusters and a list of tasks, and you have to make things work with tools you may have used only a little. The exam covers many tools and does not go very deep into any one of them. So this course teaches the one job the exam asks of each tool: the objects you write, the command that shows their status, and how to read that status when something fails. The exam groups this part into three topics, and each one turns into a set of skills you will practise.

The first topic is **implementing GitOps workflows**. GitOps means that a Git repository holds the desired state of the cluster, and a controller in the cluster keeps the cluster equal to that state. You will learn to:

- Render the manifests for each environment with Kustomize overlays and Helm charts.
- Deliver an application from a Git repository with Argo CD, and keep the cluster in line with Git through automated sync.
- Create many applications at once with an ApplicationSet, and limit a team to its own repository and namespace with an AppProject.
- Find out why an Argo CD application is out of sync or unhealthy, and fix it in Git.
- Do the same delivery with Flux, so you can choose either tool on exam day.

A GitOps controller only delivers what lands in Git, so the second topic is **building continuous integration and continuous delivery (CI/CD) pipelines integrated with Kubernetes**. You will learn to:

- Write Tekton Tasks and Pipelines that run each step as a container in a pod.
- Read a failed pipeline run and find the step that broke.
- Start a pipeline from a Git push, publish a new image tag and commit that tag to the GitOps repository.

The third topic is **progressive delivery**: sending a new version to users a step at a time and stopping when it misbehaves. You will learn to:

- Release a new version as a canary with Argo Rollouts, and promote or abort it.
- Run a blue/green release that checks a Prometheus metric before it switches traffic.
- Run an automatic canary with Flagger, the other tool the exam allows.

Everything is built and checked on **Kubernetes 1.35**, the version the exam uses, with pinned versions of each tool.

## The words this course uses

The pages use the tools' own terms, because those are the words you meet in the product, the logs and the exam. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

The **desired state** is what the files in the Git repository say the cluster should run. The **live state** is what the cluster runs right now. A **GitOps controller**, for example Argo CD or Flux, runs inside the cluster, reads the desired state from Git and changes the live state to match it. That process is called **reconciliation**, and one pass of it is a **sync**. When the live state differs from Git, the difference is called **drift**.

A few more terms describe how a change gets into Git and then into the cluster:

| Term | What it means |
| --- | --- |
| Manifest | A YAML file that describes one or more Kubernetes objects |
| Overlay | A Kustomize folder that changes a shared base for one environment |
| Chart | A Helm package of templates and default values |
| Pipeline | A list of tasks that a CI system runs in order, for example test, build and publish |
| Canary | A new version that gets a small share of the traffic before it gets all of it |
| Blue/green | Two full versions side by side, with traffic switched from the old one to the new one in one step |

## The example app in your playground

Every playground and lab runs the same small set of workloads. `scout` is a small web application (podinfo) that answers on port `9898`, reports its own version and exposes metrics. `probe` is an HTTP echo server (go-httpbin) on port `8080`. You send your test requests from the `shuttle` pod, a client with `curl`. The main team's workloads run in the `starfleet` namespace, and a second team, used where a module needs two tenants, works in the `outpost` namespace.

Most playgrounds also run **Gitea**, a small Git server, inside the cluster. It holds the Git repositories that Argo CD, Flux and Tekton read and write, so everything works without a GitHub account. Many playgrounds and labs start with something broken on purpose. That is the material, not a fault in the course.

## How the course is laid out

The course has five sections. They follow the path of a change: first how the manifests are packaged, then how a GitOps controller delivers them, then how a pipeline produces a new version, and last how that version reaches users safely.

| Section | What it covers |
| --- | --- |
| 010 | Packaging Applications For GitOps |
| 020 | Continuous Delivery With Argo CD |
| 030 | Continuous Delivery With Flux |
| 040 | Continuous Integration Pipelines With Tekton |
| 050 | Progressive Delivery |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A broken or empty cluster, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several tasks at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, the real output, and then what that output shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type or what you will see. Never change a command to make it "look right". If the result is different from the page, that difference is the lesson.
