# Example 13 — Webhooks and Triggers

Every way a build can start, how to tell which one fired, and how to wire a real webhook in the lab.

- **Teaches:** `triggers`, `pollSCM`, `cron`, the `H` symbol, webhook configuration, `currentBuild.getBuildCauses()`, `changeSets`
- **Job type:** Pipeline
- **Duration:** 10 minutes including webhook setup
- **Cost:** none, runs against the lab's Gitea server

## Prerequisites

- [Example 11](../11-checkout-and-scm/README.md) completed — you need the `demo-app` repository and the `git-scm-creds` credential

## Step 1 — Create The Job

This example needs a job connected to SCM, so `pollSCM` and the changed-files stage have something to work with.

1. Click **New Item**, name it `example-13-triggers`, choose **Pipeline**, click **OK**.
2. Scroll to the **Pipeline** section.
3. Set **Definition** to **Pipeline script from SCM** — not **Pipeline script**.
4. **SCM**: Git. **Repository URL**: `http://gitea:3000/<your-user>/demo-app.git`. **Credentials**: `git-scm-creds`.
5. **Branch Specifier**: `*/main`.
6. **Script Path**: `Jenkinsfile`.
7. Click **Save**.
8. Commit this example's [`Jenkinsfile`](./Jenkinsfile) to the repository root on `main`, replacing whatever example 12 left there.
9. Click **Build Now** once. Triggers, like parameters, are registered when the pipeline first runs.

## Step 2 — Configure The Webhook In Gitea

1. Open `http://localhost:3000`, go to the `demo-app` repository.
2. Click **Settings > Webhooks > Add Webhook > Gitea**.
3. **Target URL**: `http://jenkins:8080/gitea-webhook/post`

   Use the hostname `jenkins`, not `localhost`. Gitea calls Jenkins from inside the compose network.
4. **HTTP Method**: POST. **POST Content Type**: `application/json`.
5. Under **Trigger On**, select **Push Events**.
6. Click **Add Webhook**.
7. Click the webhook you just created, scroll to the bottom, and click **Test Delivery**.
8. Check the **Recent Deliveries** section — a green tick means Jenkins accepted it.

## Step 3 — Trigger A Build With A Push

```bash
cd demo-app
echo "change $(date)" >> README.md
git commit -am "Trigger a build"
git push origin main
```

Within a couple of seconds Jenkins starts a build without you touching the UI.

## Expected Output

A webhook-triggered build reports:

```text
Build causes: Started by an SCM change
Trigger kind: scm
abc1234 by Gitea Admin: Trigger a build
Changed paths: README.md
```

A manually started build reports:

```text
Build causes: Started by user admin
Trigger kind: manual
No recorded changes (first build, or a manual trigger).
```

The nightly `cron` build would report `Started by timer` and run the **Nightly Only Work** stage.

## The Triggers

| Trigger | Fires when |
| --- | --- |
| `pollSCM('H/5 * * * *')` | Jenkins checks the repository every ~5 minutes and builds if the revision changed |
| `cron('H 2 * * *')` | On a schedule, regardless of whether anything changed |
| `upstream(upstreamProjects:, threshold:)` | Another job finishes |
| `githubPush()` | A GitHub webhook arrives. Needs the GitHub plugin, not installed in this lab |

A webhook needs no `triggers` entry at all for Multibranch jobs — the branch source handles it. For a single Pipeline job, tick **Poll SCM** or **Trigger builds remotely** in the job configuration, or keep `pollSCM` as the declaration.

## Why `H` Matters

`H` means "hashed", not "hourly". Jenkins hashes the job name to pick a consistent but arbitrary value within the allowed range.

- `cron('0 2 * * *')` — 200 jobs all fire at exactly 02:00 and flatten the controller
- `cron('H 2 * * *')` — the same 200 jobs spread across 02:00 to 02:59, each one at a stable time

Use `H` in the minutes field of every scheduled trigger. `H/5` likewise spreads five-minute polls rather than aligning them all to :00, :05, :10.

## Webhooks Beat Polling

Polling every minute across 200 jobs is roughly 288,000 git operations a day to discover a handful of commits. It loads the controller, the agents, and the git server, and it still adds up to a minute of latency.

Keep `pollSCM` only as a fallback for repositories that genuinely cannot reach Jenkins — an air-gapped network, or a git host you do not administer. Five minutes is a sensible floor.

## Real GitHub Webhooks

```text
Payload URL:  https://your-jenkins.example.com/github-webhook/
Content type: application/json
Secret:       set one, and configure the same value in Jenkins
Events:       Just the push event
```

This requires Jenkins to be reachable from the public internet, which the local lab is not. The AWS lab in [02-installation/aws-ec2-single-instance](../../../02-installation/aws-ec2-single-instance/README.md) gives you a publicly addressable Jenkins if you want to try it end to end.

Always set the webhook secret. Without it, anyone who learns your Jenkins URL can forge push notifications.

## What To Look At In The UI

- The build page shows **Started by an SCM change** with the triggering commit linked.
- **Changes** on the job page lists commits per build — the same data the `changeSets` stage reads.
- Gitea's **Recent Deliveries** panel shows the exact JSON payload and Jenkins' HTTP response. This is the first place to look when a webhook does not fire.
- **Manage Jenkins > System Log** records webhook receipt on the Jenkins side.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh github-integration/13-webhooks-and-triggers/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Webhook delivery fails with connection refused | Target URL uses `localhost`. Use `http://jenkins:8080/gitea-webhook/post`. |
| Delivery succeeds but no build starts | The job is not connected to that repository. It must be **Pipeline script from SCM**, pointing at the same URL. |
| `403 No valid crumb` | Jenkins CSRF protection. The `/gitea-webhook/post` and `/github-webhook/` endpoints are exempt — check you have the path exactly right. |
| Triggers do not appear in the job config | Run the job once. `triggers` is registered on first execution. |
| Nightly stage never runs | It fires at the hashed time in the 02:00 hour. Test the logic by temporarily changing `cron('H 2 * * *')` to `cron('H/2 * * * *')`. |
| `changeSets` is always empty | Expected on the first build and on manual builds with no new commits. |

## Cleanup

1. Open the job, click **Delete Pipeline**, confirm.
2. In Gitea, go to the repository's **Settings > Webhooks** and delete the webhook. Left in place it will keep hitting a job that no longer exists.

## Next

[Example 14 — Tag-Based Release](../14-tag-based-release/README.md)
