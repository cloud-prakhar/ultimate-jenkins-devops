# Example 06 — Post Conditions and Notifications

Every `post` block in one pipeline, with a parameter that lets you force each build result and watch which blocks fire.

- **Teaches:** `always`, `success`, `unstable`, `failure`, `changed`, `fixed`, `regression`, `aborted`, stage-level vs pipeline-level `post`, `currentBuild`
- **Job type:** Pipeline
- **Duration:** 3 minutes
- **Cost:** none, runs in the local lab

## Prerequisites

- [Example 05](../05-artifacts-and-test-reports/README.md) completed — you should already know the difference between UNSTABLE and FAILURE

## Jenkins UI Steps

1. Click **New Item**, name it `example-06-post`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now** to register the parameter.
4. Reload the job page. Now run this exact sequence with **Build with Parameters**, checking the console output after each one:
   1. **OUTCOME** = `success`
   2. **OUTCOME** = `failure`
   3. **OUTCOME** = `failure` again
   4. **OUTCOME** = `success`
5. To see the `aborted` block, start a build with **OUTCOME** = `success`, then immediately click the red X next to it in **Build History**.

The sequence matters. `changed`, `fixed`, and `regression` compare against the *previous* build, so they only reveal themselves across a run of builds.

## Expected Output

| Build | OUTCOME | Result | Post blocks that fire |
| --- | --- | --- | --- |
| #2 | success | SUCCESS | `always`, `success`, `changed` (first result after #1) |
| #3 | failure | FAILURE | `always`, `failure`, `changed` |
| #4 | failure | FAILURE | `always`, `failure`, `regression` — no `changed`, the result is the same as #3 |
| #5 | success | SUCCESS | `always`, `success`, `changed`, `fixed` |
| aborted | success | ABORTED | `always`, `aborted`, `changed` |

Build #5 is the interesting one. Both `changed` and `fixed` fire, and this is the notification you actually want to send — "the build is green again" — rather than repeating a failure alert on every red build.

## What To Look At In The UI

- **Build History** in the sidebar color-codes the sequence: blue, red, red, blue. The `regression` block firing only on the second red is visible in the console of build #4.
- Each build's console ends with the `always` block printing `Result:` and `duration:` from `currentBuild`.
- The **Build** stage has its own `post { success { } }`. In the console it fires immediately after the Build stage, before Test starts — not at the end of the pipeline.

## Notification Patterns

The example echoes instead of sending, because the lab installs no Slack or SMTP plugin. The real calls are in the comments. The pattern worth copying:

| Block | Send what |
| --- | --- |
| `failure` | Alert the team, once |
| `regression` | Escalate — this is the second failure in a row |
| `fixed` | All-clear |
| `changed` | Any state transition, if you prefer a single rule |
| `success` | Usually nothing. Notifying on every green build trains people to ignore the channel. |

Wiring `always` to a chat channel is the most common mistake here: it produces a message per build, and within a week nobody reads them.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/06-post-conditions-and-notifications/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `fixed` never fires | It needs a red build immediately followed by a green one. Follow the sequence above exactly. |
| `regression` never fires | It needs two consecutive failures. |
| `changed` fires on the very first build | There is no previous build to compare against; Jenkins treats that as a change. |
| Workspace not cleaned on failure | `cleanWs()` is inside `always`, so it runs regardless. If it did not, check whether the agent went offline. |

## Cleanup

Open the job, click **Delete Pipeline**, confirm.

## Next

[Example 07 — Docker Agents](../07-docker-agents/README.md)
