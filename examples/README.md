# Example Pipelines

Fifteen self-contained, runnable Jenkins pipeline examples for demonstrations, workshops, and self-study. Each one is a single `Jenkinsfile` with a matching README that walks through the Jenkins UI steps, the expected output, and how to clean up.

These are demonstration examples, not a numbered learning module. Work through them in order for a guided tour of declarative pipeline syntax, or pull one out standalone when you need to show a specific concept.

## Prerequisites

- A running lab from [00-local-lab-setup](../00-local-lab-setup/README.md) — Jenkins on `http://localhost:8080`, one agent labelled `linux docker`, Gitea on `http://localhost:3000`
- Familiarity with [03-jenkins-ui](../03-jenkins-ui/README.md) — creating a job and reading console output
- No cloud account and no cost. Everything runs locally in Docker.

Verify the lab before starting:

```bash
cd 00-local-lab-setup
./scripts/verify-lab.sh
```

## The Examples

| # | Example | Teaches | Job type | Duration |
| --- | --- | --- | --- | --- |
| 01 | [Hello Multi-Stage](./pipeline-scripts/01-hello-multistage/README.md) | agent, options, stages, post | Pipeline | 1 min |
| 02 | [Parameters and Environment](./pipeline-scripts/02-parameters-and-environment/README.md) | `parameters`, `environment`, `params` vs `env` | Pipeline | 2 min |
| 03 | [Parallel Stages](./pipeline-scripts/03-parallel-stages/README.md) | `parallel`, `failFast`, stash, executor limits | Pipeline | 2 min |
| 04 | [Conditional Stages](./pipeline-scripts/04-conditional-stages/README.md) | `when`, `anyOf`/`allOf`/`not`, `beforeAgent` | Pipeline | 3 min |
| 05 | [Artifacts and Test Reports](./pipeline-scripts/05-artifacts-and-test-reports/README.md) | `junit`, `archiveArtifacts`, `publishHTML` | Pipeline | 2 min |
| 06 | [Post Conditions](./pipeline-scripts/06-post-conditions-and-notifications/README.md) | every `post` block, `currentBuild` | Pipeline | 3 min |
| 07 | [Docker Agents](./pipeline-scripts/07-docker-agents/README.md) | per-stage docker agents, `agent none` | Pipeline | 5 min |
| 08 | [Credentials and Secrets](./pipeline-scripts/08-credentials-and-secrets/README.md) | `withCredentials`, masking, leak patterns | Pipeline | 5 min |
| 09 | [Error Handling and Retries](./pipeline-scripts/09-error-handling-and-retries/README.md) | `retry`, `timeout`, `catchError`, `warnError` | Pipeline | 3 min |
| 10 | [Scripted Multi-Stage](./pipeline-scripts/10-scripted-multistage/README.md) | `node {}`, dynamic stages, try/catch/finally | Pipeline | 2 min |
| 11 | [Checkout and SCM](./github-integration/11-checkout-and-scm/README.md) | `checkout scm`, GitSCM extensions, commit metadata | Pipeline | 5 min |
| 12 | [Multibranch and Pull Requests](./github-integration/12-multibranch-and-pull-requests/README.md) | `BRANCH_NAME`, `CHANGE_ID`, `changeRequest()` | Multibranch | 10 min |
| 13 | [Webhooks and Triggers](./github-integration/13-webhooks-and-triggers/README.md) | `triggers`, webhooks vs polling, build causes | Pipeline | 10 min |
| 14 | [Tag-Based Release](./github-integration/14-tag-based-release/README.md) | `TAG_NAME`, semver validation, changelog | Multibranch | 10 min |
| 15 | [Commit Status and Checks](./github-integration/15-commit-status-and-checks/README.md) | reporting build status back to the SCM | Multibranch | 5 min |

Examples 01-10 need nothing but the lab. Examples 11-15 need a git repository — use the lab's Gitea server, which speaks the same protocol as GitHub.

## How To Run Any Example

Each example README repeats these steps with its own specifics. The common shape:

1. Open `http://localhost:8080` and log in with the credentials from your `00-local-lab-setup/.env`.
2. Click **New Item** in the left sidebar.
3. Enter a name, for example `example-01-hello-multistage`.
4. Select **Pipeline**, then click **OK**.
5. Scroll to the **Pipeline** section at the bottom.
6. Leave **Definition** as **Pipeline script**.
7. Paste the contents of the example's `Jenkinsfile` into the **Script** box.
8. Click **Save**.
9. Click **Build Now** in the left sidebar.
10. Click the build number under **Build History**, then **Console Output**.

For examples 12, 14, and 15 use **Multibranch Pipeline** instead of **Pipeline** — those READMEs cover the extra source configuration.

## GitHub vs the Lab

The lab ships Gitea rather than GitHub so the whole environment stays local, free, and offline-capable. For everything in examples 11-14 this makes no difference: `checkout`, branch discovery, PR discovery, tag discovery, and webhooks all behave the same way, and switching to GitHub means changing a URL and a credential.

Example 15 is the honest exception. Posting commit status to GitHub needs the `github` plugin, which the lab does not install, plus a Jenkins that GitHub can reach over the internet. That example runs end to end regardless, guards the plugin call, and shows the raw REST equivalent so the mechanism is visible.

## Validation

Lint every example against your running Jenkins before demonstrating them:

```bash
export JENKINS_URL=http://localhost:8080
export JENKINS_USER=admin
export JENKINS_TOKEN='<your-api-token-or-password>'
./examples/validate-examples.sh
```

The script posts each `Jenkinsfile` to Jenkins' declarative linter and reports pass or fail per file. Generate an API token at **Your username > Configure > API Token > Add new Token**.

Scripted pipelines cannot be validated by the declarative linter, so example 10 is reported as skipped. That is expected.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Build queues forever, "waiting for next available executor" | No agent matches `label 'linux'` | Check **Manage Jenkins > Nodes**; the lab agent should be online. `docker compose ps agent` in `00-local-lab-setup`. |
| `No such DSL method 'publishHTML'` | Plugin missing | The lab preinstalls it. On another Jenkins, install `htmlpublisher`. |
| Parameters do not appear in the UI | Normal on the first build | Run the job once. `parameters` is applied when the pipeline first executes, then **Build with Parameters** appears. |
| `when { branch 'main' }` stages always skip | Job is a plain Pipeline, not Multibranch | `BRANCH_NAME` is only set by Multibranch jobs. Expected in a script-pasted job. |
| Published HTML report renders unstyled | Jenkins Content-Security-Policy blocks inline CSS | Lab-only workaround: **Manage Jenkins > Script Console**, run `System.setProperty("hudson.model.DirectoryBrowserSupport.CSP", "sandbox allow-scripts; default-src 'self'; style-src 'self' 'unsafe-inline';")`. Do not relax CSP on a shared Jenkins. |
| `docker: command not found` in a build | Stage is running somewhere without the Docker CLI | Use `agent { label 'linux' }` for Docker steps; the lab agent has the CLI and the mounted socket. |

More in [14-troubleshooting](../14-troubleshooting/README.md).

## Cleanup

Delete the demo jobs when you are done:

1. Open the job.
2. Click **Delete Pipeline** (or **Delete Multibranch Pipeline**) in the left sidebar.
3. Confirm.

Then remove any images example 07 left behind, and stop the lab:

```bash
docker image prune -f
cd 00-local-lab-setup && ./scripts/stop-lab.sh
```

To reset Jenkins entirely, including all jobs and build history:

```bash
cd 00-local-lab-setup && ./scripts/reset-lab.sh
```

## Related Modules

- [05-pipelines](../05-pipelines/README.md) — pipeline concepts
- [06-declarative-pipelines](../06-declarative-pipelines/README.md) — declarative syntax reference
- [07-scripted-pipelines](../07-scripted-pipelines/README.md) — scripted syntax reference, pairs with example 10
- [09-docker-integration](../09-docker-integration/README.md) — pairs with example 07
- [12-security](../12-security/README.md) — pairs with example 08
- [templates](../templates/) — production-shaped starting points rather than teaching examples
