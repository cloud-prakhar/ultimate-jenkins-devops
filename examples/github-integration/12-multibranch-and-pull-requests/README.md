# Example 12 — Multibranch and Pull Requests

A Multibranch Pipeline that discovers branches and pull requests automatically, and runs a different set of stages for each.

- **Teaches:** Multibranch job setup, `BRANCH_NAME`, `CHANGE_ID`, `CHANGE_TARGET`, `changeRequest()`, branch pattern matching
- **Job type:** Multibranch Pipeline
- **Duration:** 10 minutes including setup
- **Cost:** none, runs against the lab's Gitea server

## Prerequisites

- [Example 11](../11-checkout-and-scm/README.md) completed — you need the `demo-app` repository in Gitea and the `git-scm-creds` credential
- [Example 04](../../pipeline-scripts/04-conditional-stages/README.md) completed — this is where `when { branch 'main' }` finally does something

## Step 1 — Commit The Jenkinsfile To The Repository

A Multibranch job reads the Jenkinsfile from the repository, not from a text box. Push it first.

```bash
git clone http://localhost:3000/<your-gitea-user>/demo-app.git
cd demo-app
cp /path/to/examples/github-integration/12-multibranch-and-pull-requests/Jenkinsfile ./Jenkinsfile
git add Jenkinsfile
git commit -m "Add pipeline"
git push origin main
```

Or paste the file through the Gitea web UI: open the repository, click **Add File > New File**, name it `Jenkinsfile`, paste, and commit.

## Step 2 — Create Branches To Discover

```bash
git checkout -b develop && git push origin develop
git checkout -b feature/add-login && git push origin feature/add-login
git checkout main
```

## Step 3 — Create The Multibranch Job

1. Click **New Item**.
2. Name it `example-12-multibranch`.
3. Select **Multibranch Pipeline** — not **Pipeline** — and click **OK**.
4. Under **Branch Sources**, click **Add source** and choose **Gitea**.
5. **Server**: `http://gitea:3000`. If no server is listed, add one under **Manage Jenkins > System > Gitea Servers** first.
6. **Owner**: your Gitea username. **Repository**: `demo-app`.
7. **Credentials**: select `git-scm-creds`.
8. Under **Behaviours**, confirm **Discover branches** and **Discover pull requests from origin** are both present. Add them with **Add** if not.
9. Under **Scan Repository Triggers**, tick **Periodically if not otherwise run** and set **1 minute** for the lab.
10. Click **Save**.

Jenkins immediately scans the repository and creates one sub-job per branch.

## Step 4 — Open A Pull Request

1. In Gitea, open the `demo-app` repository.
2. Click **Pull Requests > New Pull Request**.
3. Set the base to `main` and the compare branch to `feature/add-login`.
4. Give it a title and click **Create Pull Request**.
5. Back in Jenkins, open the Multibranch job and click **Scan Repository Now** in the left sidebar.
6. A **Pull Requests** tab appears alongside **Branches**.

## Expected Output

The job page shows a **Branches** tab with `main`, `develop`, and `feature/add-login`, and a **Pull Requests** tab with `PR-1`.

Open each build's **Console Output** and compare the Context stage:

For `main`:

```text
BRANCH_NAME   = main
CHANGE_ID     = (not a pull request)
IS_PR         = false
```

For `PR-1`:

```text
BRANCH_NAME   = PR-1
CHANGE_ID     = 1
CHANGE_TARGET = main
CHANGE_BRANCH = feature/add-login
CHANGE_TITLE  = Add login
IS_PR         = true
```

Which stages run:

| Build | Stages that run |
| --- | --- |
| `main` | Build, Fast Tests, Full Test Suite, Publish Release |
| `develop` | Build, Fast Tests, Full Test Suite, Publish Snapshot |
| `feature/add-login` | Build, Fast Tests, Feature Branch |
| `PR-1` | Build, Fast Tests, PR Checks, PR To Main Only |

The PR build deliberately skips the Full Test Suite. That is the design: pull request builds should be fast, and the expensive suite runs on `main` where a slow pipeline blocks nobody's review.

## What To Look At In The UI

- The Multibranch job page is a folder. Each branch is a real job with its own build history, its own configuration, and its own retention.
- **Scan Repository Log** in the left sidebar shows exactly what Jenkins found and which branches it created or removed.
- Delete a branch in Gitea and rescan — Jenkins marks the sub-job as an orphan and removes it. **Orphaned Item Strategy** in the job configuration controls how long they linger.
- **Blue Ocean** renders Multibranch jobs well; the branch and PR selector at the top is easier to navigate than the classic view.

## Environment Variables Reference

| Variable | Set when |
| --- | --- |
| `BRANCH_NAME` | Always in a Multibranch job. For a PR it is `PR-<number>`, not the source branch |
| `CHANGE_ID` | Pull request builds only. The reliable "is this a PR?" test |
| `CHANGE_TARGET` | The base branch the PR merges into |
| `CHANGE_BRANCH` | The PR's source branch |
| `CHANGE_AUTHOR`, `CHANGE_TITLE`, `CHANGE_URL` | PR metadata |

## Running It Against Real GitHub

Replace the Gitea branch source with **GitHub** at step 4. That requires the **GitHub Branch Source** plugin, which the lab does not install — add it under **Manage Jenkins > Plugins** if you want to try it. Configure it with a GitHub personal access token holding `repo` scope, and the rest of the Jenkinsfile is unchanged: `CHANGE_ID`, `CHANGE_TARGET`, and `changeRequest()` behave identically.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh github-integration/12-multibranch-and-pull-requests/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| No branches discovered | Check **Scan Repository Log**. Usually a wrong owner or repository name, or a missing credential. |
| `Jenkinsfile not found` | The file must be at the repository root and named exactly `Jenkinsfile`. |
| Pull Requests tab never appears | The **Discover pull requests from origin** behaviour is missing. Add it in the branch source configuration and rescan. |
| Gitea server not in the dropdown | Add it under **Manage Jenkins > System > Gitea Servers**, with URL `http://gitea:3000`. |
| Builds do not start on push | Scanning is periodic. Set up a webhook — [example 13](../13-webhooks-and-triggers/README.md) covers it. |
| `CHANGE_TARGET` is null in a PR build | Some branch sources only set it for PRs discovered from origin, not from forks. |

## Cleanup

1. Open the Multibranch job, click **Delete Multibranch Pipeline**, confirm. This deletes every branch sub-job with it.
2. Leave the Gitea repository — examples 13 and 14 reuse it.

## Next

[Example 13 — Webhooks and Triggers](../13-webhooks-and-triggers/README.md)
