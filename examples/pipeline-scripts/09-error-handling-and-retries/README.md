# Example 09 — Error Handling and Retries

Five ways to handle a failing step, and guidance on which to reach for.

- **Teaches:** `retry`, `timeout`, `catchError`, `warnError`, `try`/`catch`/`finally`, setting `currentBuild.result` deliberately
- **Job type:** Pipeline
- **Duration:** 3 minutes — one stage deliberately waits 20 seconds
- **Cost:** none, runs in the local lab

## Prerequisites

- [Example 06](../06-post-conditions-and-notifications/README.md) completed — you should know what UNSTABLE means before deciding when to set it

## Jenkins UI Steps

1. Click **New Item**, name it `example-09-error-handling`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now**.
4. Open **Console Output** and watch it live. The Timeout stage pauses for 20 seconds before aborting.
5. When the build finishes, look at the **Stage View** on the job page.

## Expected Output

The build finishes **UNSTABLE** and every stage runs:

```text
[Pipeline] { (Retry A Flaky Step)
attempt 1
simulated transient failure
ERROR: script returned exit code 1
Retrying
attempt 2
simulated transient failure
Retrying
attempt 3
succeeded on attempt 3

[Pipeline] { (Timeout A Slow Step)
starting slow work
Cancelling nested steps due to timeout
ERROR: Timeout has been exceeded

[Pipeline] { (Continue On Non-Critical Failure)
WARNING: Optional lint step failed; continuing
Pipeline continues

[Pipeline] { (Handle And Inspect An Error)
Caught: script returned exit code 42
finally always runs — use it for cleanup

Final result: UNSTABLE
Finished: UNSTABLE
```

## What To Look At In The UI

- **Stage View** shows the difference between stage result and build result. Timeout A Slow Step is red, Continue On Non-Critical Failure is yellow, and the pipeline as a whole is yellow — because `catchError` was told `stageResult: 'FAILURE'` but `buildResult: 'UNSTABLE'`.
- Hover a red or yellow stage cell for the error message, without opening the console.
- **Console Output** shows `Retrying` between attempts. Each retry re-runs the whole block, so anything non-idempotent inside it runs again too.

## Choosing A Mechanism

| Construct | Result | Use for |
| --- | --- | --- |
| `retry(n) { }` | Retries the block up to n times | Genuinely transient failures — network, registry, flaky external service |
| `timeout(time:, unit:) { }` | Aborts the block | Anything that could hang: a shell step, an `input` gate, a deploy wait |
| `catchError(buildResult:, stageResult:) { }` | Continues, sets results you choose | When you want the pipeline to finish but the failure to be visible |
| `warnError('msg') { }` | Continues, marks UNSTABLE | Shorthand for optional work — linters, metrics pushes, changelog generation |
| `try`/`catch`/`finally` | Whatever you write | When you need to inspect the exception or guarantee cleanup |
| `error('msg')` | Fails immediately | Unmet preconditions. Most failures belong here. |

The default should be to fail. Every one of the constructs above hides a signal in exchange for finishing the build, and that is only worth it when you have decided the signal is not worth blocking on.

## When Not To Retry

Retrying a deterministic failure costs three times the compute and delays the real diagnosis. Before wrapping a step in `retry`, check that it can actually succeed on a second attempt without anything else changing.

Retries also need the block to be idempotent. `retry(3) { sh 'kubectl create ...' }` fails on attempt two with "already exists" — use `kubectl apply` instead.

## Pipeline-Level `retry(2)`

The `retry(2)` in the `options` block is different from the step. It retries the entire pipeline, and only when the *agent* fails — a disconnect, an evicted pod. Ordinary step failures do not trigger it. It is useful with spot or preemptible agents, and pointless on a stable static agent.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/09-error-handling-and-retries/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| The retry stage fails all three attempts | The counter file lives in `${WORKSPACE}`; a `cleanWs()` between attempts would reset it. Check nothing else clears the workspace mid-build. |
| The retry stage passes on attempt 1 | A previous build left `.attempt` behind. The pipeline's `cleanWs()` in `post` should prevent it — rerun after a clean build. |
| Build is FAILURE, not UNSTABLE | A stage escaped its `catchError` or `warnError` wrapper. Check the console for which one. |
| The timeout stage takes the full 60 seconds | The `timeout` wrapper is missing or outside the `sh` step. |

## Cleanup

Open the job, click **Delete Pipeline**, confirm.

## Next

[Example 10 — Scripted Multi-Stage](../10-scripted-multistage/README.md)
