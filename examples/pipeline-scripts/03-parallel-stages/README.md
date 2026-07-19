# Example 03 — Parallel Stages

Runs three independent checks concurrently, and shows that parallelism is bounded by available executors rather than by the Jenkinsfile.

- **Teaches:** `parallel`, `failFast`, `stash`/`unstash`, executor limits
- **Job type:** Pipeline
- **Duration:** 2 minutes
- **Cost:** none, runs in the local lab

## Prerequisites

- [Example 01](../01-hello-multistage/README.md) completed
- Lab running with the default `JENKINS_AGENT_EXECUTORS=2`

## Jenkins UI Steps

1. Click **New Item**, name it `example-03-parallel`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now**.
4. While the build runs, open **Blue Ocean** from the left sidebar of the Jenkins home page and click into the running build. The parallel branches render as three lanes side by side.
5. When it finishes, go back to the classic view and open the build's **Console Output**.
6. Open **Manage Jenkins > Nodes > local-linux-agent** during a build to watch both executors go busy.

## Expected Output

The console interleaves output from the three branches, each line tagged with its branch name:

```text
[Lint] linting...
[Unit Tests] running unit tests...
[Integration Tests] running integration tests...
[Lint] no lint errors
[Unit Tests] 12 passed
[Integration Tests] 4 passed
```

Total wall time for the Verify stage is roughly 13-15 seconds, not the 23 seconds the three sleeps add up to — but also not the 10 seconds you would get with three free executors.

## What To Look At In The UI

- **Blue Ocean** is the clearest view of parallel work; the classic Stage View collapses parallel branches into one column.
- **Manage Jenkins > Nodes** shows two executors busy and the third branch waiting. With `JENKINS_AGENT_EXECUTORS=2`, three branches cannot all run at once.
- Set `JENKINS_AGENT_EXECUTORS=3` in `00-local-lab-setup/.env`, restart the lab, and rerun to see the Verify stage drop to about 10 seconds.

## Why Stash

Parallel branches may run in different workspaces, so files written in the Build stage are not reliably visible to them. `stash` archives files on the controller; `unstash` retrieves them wherever the branch runs. Stashes are deleted when the build ends.

Use `stash` for small handoffs — a jar, a build directory. For anything large, publish to a real artifact repository instead; stashes cost controller disk and network on every build.

## Experiment: failFast

The `failFast true` line aborts the remaining branches as soon as one fails. To see it, change the Lint branch to `sh 'exit 1'` and rerun — the other two branches are cancelled mid-flight.

Fast feedback is the argument for it. The argument against: you lose the full report, so a developer fixes the lint error and then discovers the test failures on the next run. Leave it off when you want everything reported at once.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/03-parallel-stages/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Branches run one after another | Only one executor is free. Check **Manage Jenkins > Nodes**, or raise `JENKINS_AGENT_EXECUTORS`. |
| `No such saved stash 'app'` | The Build stage failed before stashing, or you renamed the stash in only one place. |
| Blue Ocean link missing | The `blueocean` plugin is preinstalled in the lab; on another Jenkins, install it or use the Stage View. |

## Cleanup

Open the job, click **Delete Pipeline**, confirm.

## Next

[Example 04 — Conditional Stages](../04-conditional-stages/README.md)
