# Get Your Machine Ready

Every playground and lab in this course runs on your own machine, in a small Kubernetes cluster. A tool called `astrona` builds it for you, sets it up, grades your work and removes it again. This page gets your machine ready: first the tools you need, then the handful of `astrona` commands you will use every day, and last what to do when a start goes wrong.

## What you need

Every section needs the same base set of tools. Install these before you start:

- **A container engine:** Docker or Podman. The cluster runs inside it.
- **`kind`:** runs Kubernetes inside the container engine.
- **`kubectl`:** talks to the cluster. It also has Kustomize built in.
- **The astrona command-line tool.**
- **`git`:** clones and pushes to the Git server that runs inside the playground.
- **`jq` and `yq`:** read the JSON and YAML that the tools print, so you can pick out one field. The exam machines have `yq` too.
- **A web browser:** some modules open the Argo CD and Gitea web pages through `kubectl port-forward`.

Each tool in this course also has its own command-line tool. Install them when you reach the section that uses them; each module's landing page names the version it was checked with.

| Command-line tool | Used in |
| --- | --- |
| `helm` | Packaging with Helm |
| `argocd` | Continuous delivery with Argo CD |
| `flux` | Continuous delivery with Flux |
| `tkn` | Tekton pipelines |
| `kubectl argo rollouts` (a `kubectl` plugin) | Progressive delivery with Argo Rollouts |

The playgrounds and labs also need **outbound internet** while they start. They download the tools' container images and some Helm charts. Without outbound internet, those starts fail with network errors that have nothing to do with the tool you are learning.

Several tools run at once in some playgrounds, for example Argo CD, Tekton and Gitea. Give your container engine at least 8 GiB of memory, and run one playground or lab at a time.

You do not have to check all of this by hand. Let `astrona` look at your machine for you:

```sh
astrona setup
```

`astrona setup` looks at what is missing, shows you each step it would take, and asks before it does anything. On macOS it can install `kind`, `kubectl` and Podman. Install `git`, `jq`, `yq` and the tool command-line tools yourself.

Later, you can check your machine at any time:

```sh
astrona check
```

## The commands you use every day

Once your machine is ready, you need only a handful of `astrona` commands. Each module page and lab page shows the exact command to copy, so you do not need to remember paths. This section walks through them in the order you meet them: sign in, start, pause, submit and clean up.

Labs from the course catalog are tied to your Astrona account, so you sign in first:

```sh
astrona login
```

Next you start a playground or a lab. Each module page and lab page shows the exact `astrona run` command for it. It looks like this:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-01/playground
```

When the cluster is ready, `kubectl` already points at it.

A chapter that sends you to a lab asks you to pause the playground first. Pausing frees your machine's memory but keeps everything you built:

```sh
astrona stop <name>
```

When the lab is done, start the playground again and carry on where you left off:

```sh
astrona start <name>
```

Inside a lab, you send your work for grading with `astrona submit`. The grader checks the live cluster. It sends real requests from the `shuttle` pod and reads the status of the objects you created, so your work has to actually deliver the right version, not only make an error message go away. Each lab page shows the exact command:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

You can submit as often as you like.

When you are done with a playground or a lab, remove it:

```sh
astrona destroy <name>
```

The name is the environment's name, printed by `astrona run` and shown on each page (for example `ats-018-playground-010-01`). It is not the folder path. To see what is on your machine, list it:

```sh
astrona list
```

> [!WARNING]
> **Run one environment at a time.** Each playground and lab is a whole cluster. Two running at once slow your machine down, and it is easy to send a command to the wrong one. Pause or destroy the playground before you start the lab.

## When a start goes wrong

Sometimes a playground or lab does not start cleanly. Ask `astrona` what is wrong before you try anything else:

```sh
astrona doctor
```

It checks your machine, the lab's configuration and the running lab, and tells you how to fix what it finds.

If a start fails while it downloads something, check your network first. If pods stay in `Pending` or the start is very slow, check how much memory your container engine has. Remember also that a playground that starts with a failing application is often broken on purpose: the module's landing page tells you when that is the case. With your machine ready and these commands at hand, you can start the first module.
