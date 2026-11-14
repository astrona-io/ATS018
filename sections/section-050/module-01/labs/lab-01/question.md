# Question

Solve this question on: `terminal`

The `drifter` team keeps its continuous integration pipeline in the namespace `starfleet`. The Pipeline `scout-ci` clones the Git repository `scout-app` with the Task `fetch-source`, then tests it with the Task `run-tests`. Nobody has run the pipeline since the last change to `run-tests`, and the team expects it to fail.

Start the Pipeline, find out why it fails, and fix the cause. Do not delete the Task `run-tests`, do not remove the call to `test.sh` from it, and do not remove a Task from the Pipeline.

When you finish, these must be true:

- The Task `run-tests` in `starfleet` still runs `test.sh`, and its step starts in the `source` workspace.
- The Pipeline `scout-ci` still runs `fetch-source` and then `run-tests`.
- A new `PipelineRun` of `scout-ci` has the status `Succeeded`. Give its workspace `shared` a `volumeClaimTemplate`.
- The Pipeline result `version` of that run is `6.15.0`.

The `tkn` command-line tool and `kubectl` are installed. Tekton uses the Gitea repository `http://gitea-http.gitea.svc:3000/starfleet/scout-app.git`, which is public.

Check your work with `astrona submit`.
