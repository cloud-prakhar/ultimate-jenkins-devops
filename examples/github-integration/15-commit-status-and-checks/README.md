# Example 15 — Commit Status and Checks

Reports pipeline status back to the SCM, so a pull request shows green or red before anyone opens it.

- **Teaches:** commit status reporting, `githubNotify`, `publishChecks`, the raw REST equivalent, guarding optional plugin calls
- **Job type:** Multibranch Pipeline
- **Duration:** 5 minutes
- **Cost:** none, runs against the lab's Gitea server

## Honest Status

This is the one example in the folder that cannot fully demonstrate itself in the lab. Read this before running it.

| Path | Works in the lab? | Notes |
| --- | --- | --- |
| Gitea commit status | **Yes, automatically** | The Gitea plugin posts status for Multibranch builds with no Jenkinsfile code at all. You will see it in Gitea. |
| `githubNotify()` | No | Needs the `github` plugin, which the lab does not install. The call is guarded so the build still passes. |
| `publishChecks()` | No | Needs the GitHub Checks plugin plus a GitHub App. Shown as documentation only. |
| Raw REST `curl` | Yes, with a real token | Provider-agnostic. Shown so the mechanism is not hidden behind a plugin. |

The pipeline runs end to end regardless. What you are learning here is the pattern and the plumbing, not a working GitHub integration — that requires a publicly reachable Jenkins.

## Prerequisites

- [Example 12](../12-multibranch-and-pull-requests/README.md) completed — you need the `demo-app` repository, `git-scm-creds`, and a Multibranch job
- [Example 05](../../pipeline-scripts/05-artifacts-and-test-reports/README.md) completed — this example publishes JUnit results

## Step 1 — Commit The Jenkinsfile

```bash
cd demo-app
cp /path/to/examples/github-integration/15-commit-status-and-checks/Jenkinsfile ./Jenkinsfile
git commit -am "Add status reporting pipeline"
git push origin main
```

## Step 2 — Create The Multibranch Job

1. Click **New Item**, name it `example-15-checks`, choose **Multibranch Pipeline**, click **OK**.
2. Add a **Gitea** branch source pointing at `demo-app` with `git-scm-creds`, as in example 12.
3. Confirm **Discover pull requests from origin** is among the behaviours.
4. Click **Save**.

## Step 3 — See Gitea Commit Status

1. Wait for the `main` build to finish.
2. Open `http://localhost:3000`, go to `demo-app`, and click **Commits**.
3. The most recent commit shows a status icon — a green tick, a red cross, or an amber dot.
4. Hover or click it. It links back to the Jenkins build.

That status came from the Gitea plugin, not from anything in the Jenkinsfile. This is the important lesson: for the common case you do not write status-reporting code at all, you configure the branch source and the plugin does it.

## Step 4 — See It On A Pull Request

1. In Gitea, create a branch and open a pull request against `main`, as in example 12.
2. Rescan the Jenkins job.
3. Open the pull request in Gitea. The status check appears in the merge box at the bottom, and blocks or permits the merge depending on configuration.
4. To make it blocking: Gitea repository **Settings > Branches > Branch Protection**, protect `main`, and require the status check.

## Expected Output

The Jenkins console shows the guarded fallback, because the GitHub plugin is absent:

```text
[scm-status] ci/jenkins/pipeline -> PENDING: Build started (githubNotify unavailable; install the GitHub plugin to report for real)
...
Recording test results
[scm-status] ci/jenkins/pipeline -> SUCCESS: All stages passed (githubNotify unavailable; ...)
Finished: SUCCESS
```

Meanwhile Gitea shows a real green status on the commit. Both things are true at once, which is the point of the table above.

## Making The GitHub Path Real

1. **Manage Jenkins > Plugins > Available**, install **GitHub** and restart Jenkins.
2. Create a GitHub personal access token with `repo:status` scope, and add it as a **Secret text** credential with ID `github-token`.
3. Remove the `try`/`catch` guard around `githubNotify` in the helper at the bottom of the Jenkinsfile.
4. Point the Multibranch source at a GitHub repository, using the **GitHub Branch Source** plugin.
5. Jenkins must be reachable from GitHub. The local lab is not; [02-installation/aws-ec2-single-instance](../../../02-installation/aws-ec2-single-instance/README.md) gives you a publicly addressable instance.

## Three Ways To Report Status

| Mechanism | Granularity | Needs |
| --- | --- | --- |
| Branch source plugin (Gitea, GitHub) | One status per build | Nothing — automatic for Multibranch |
| `githubNotify` | One status per call, so per stage if you want | `github` plugin, a token |
| `publishChecks` | Rich Checks-tab output with annotations on specific lines | GitHub Checks plugin, a GitHub App |
| Raw REST `curl` | Whatever you write | A token. Works with any provider |

Per-stage status is worth the effort on long pipelines: a developer sees "build passed, tests failed" in the PR without opening Jenkins at all.

## Why The Helper Belongs In A Shared Library

The `notifyScm()` helper sits at the bottom of the Jenkinsfile so this example stays self-contained. In a real organization it belongs in a shared library — see [08-shared-libraries](../../../08-shared-libraries/README.md) — so every pipeline reports status with the same context strings and the same credential, and one change fixes all of them.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh github-integration/15-commit-status-and-checks/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| No status appears in Gitea | The job is not Multibranch, or the branch source is generic Git rather than Gitea. The generic Git source cannot post status. |
| `No suitable checks publisher found` | Normal — no Checks API plugin in the lab. JUnit results still publish. |
| `NoSuchMethodError: githubNotify` escapes the guard | Some Jenkins versions throw a different exception type. Widen the `catch` to `catch (Exception e)`. |
| `Could not find credentials 'github-token'` | Only relevant once you remove the guard. Create the credential first. |
| Status is stuck on PENDING | The build died before reaching a `post` block, usually an agent disconnect. Post the final status from `post { always { } }` for robustness. |

## Cleanup

1. Open the Multibranch job, click **Delete Multibranch Pipeline**, confirm.
2. If you no longer need the lab repository, delete `demo-app` in Gitea: **Settings > Delete Repository**.
3. Delete the `git-scm-creds` credential under **Manage Jenkins > Credentials**.
4. Stop the lab:

```bash
cd 00-local-lab-setup && ./scripts/stop-lab.sh
```

## Where To Go Next

You have finished the example set. Suggested continuations:

- [08-shared-libraries](../../../08-shared-libraries/README.md) — factor the repeated pieces out of these pipelines
- [15-real-world-projects/01-python-flask-todo-api](../../../15-real-world-projects/01-python-flask-todo-api/README.md) — a complete application with a real pipeline
- [11-production-grade-jenkins](../../../11-production-grade-jenkins/README.md) — running Jenkins for a team rather than a lab
