# Example 04 — Conditional Stages

Every form of the `when` directive, plus a manual approval gate.

- **Teaches:** `when` with `expression`, `branch`, `environment`, `anyOf`, `allOf`, `not`, `beforeAgent`, and `input`
- **Job type:** Pipeline
- **Duration:** 3 minutes
- **Cost:** none, runs in the local lab

## Prerequisites

- [Example 02](../02-parameters-and-environment/README.md) completed — this example assumes you know why parameters appear only after the first build

## Jenkins UI Steps

1. Click **New Item**, name it `example-04-conditionals`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now** to register the parameters.
4. Reload the job page and click **Build with Parameters**.
5. Leave **ENVIRONMENT** as `dev`, leave **RUN_SLOW_TESTS** unticked, click **Build**. Note which stages ran.
6. Click **Build with Parameters** again. Set **ENVIRONMENT** to `staging` and tick **RUN_SLOW_TESTS**. Click **Build**.
7. Click **Build with Parameters** a third time. Set **ENVIRONMENT** to `production`. Click **Build**.
8. Watch the **Stage View** on the job page. The **Production Gate** stage turns amber and pauses.
9. Hover over the paused stage and click **Promote** in the popup. Alternatively open **Console Output** and click the **Promote** link inline.

## Expected Output

| Build | ENVIRONMENT | Slow tests | Stages that run |
| --- | --- | --- | --- |
| #2 | `dev` | off | Build, Fast Tests, Deploy Dev, Non-Production Cleanup |
| #3 | `staging` | on | Build, Fast Tests, Slow Tests, Deploy Staging or Prod, Non-Production Cleanup |
| #4 | `production` | off | Build, Fast Tests, Deploy Staging or Prod, Production Gate, then finishes after you approve |

**Main Branch Only** is skipped in every build. That is correct: `env.BRANCH_NAME` is null in a plain Pipeline job, so `when { branch 'main' }` never matches. [Example 12](../../github-integration/12-multibranch-and-pull-requests/README.md) runs the same condition in a Multibranch job where it does match.

## What To Look At In The UI

- **Stage View** renders skipped stages as pale grey cells with no duration. Comparing builds #2 through #4 side by side makes the routing visible at a glance.
- The paused **Production Gate** stage shows an amber cell with a **Promote** button. The build holds an executor while it waits — which is why the `timeout(time: 5, unit: 'MINUTES')` wrapper matters. Let one build time out to see it abort cleanly.
- **Console Output** of build #4 shows `Approved by admin` after you click Promote.

## The Conditions

| Directive | Matches when |
| --- | --- |
| `expression { return params.X }` | Arbitrary Groovy returns true. The general-purpose escape hatch. |
| `branch 'main'` | `BRANCH_NAME` equals `main`. Multibranch jobs only. |
| `environment name: 'K', value: 'v'` | An environment variable has an exact value. |
| `anyOf { a; b }` | At least one nested condition matches. |
| `allOf { a; b }` | Every nested condition matches. |
| `not { a }` | The nested condition does not match. |
| `beforeAgent true` | Evaluate before allocating an agent. Saves agent startup for stages that will be skipped. |

`beforeAgent true` is worth reaching for whenever a stage declares its own agent — without it, Jenkins spins up a container or a cloud node and then decides not to use it.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/04-conditional-stages/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Every conditional stage is skipped | You clicked **Build Now** instead of **Build with Parameters**, so defaults applied. |
| **Main Branch Only** never runs | Expected in a Pipeline job. See example 12. |
| The build hangs at Production Gate | It is waiting for you. Click **Promote**, or **Abort** to cancel. It self-aborts after 5 minutes. |
| `input` approval is available to anyone | The example omits `submitter` for lab simplicity. In production add `submitter: 'release-managers'` and see [12-security](../../../12-security/README.md). |

## Cleanup

Open the job, click **Delete Pipeline**, confirm. If a build is still paused at the approval gate, abort it first with the red X next to it in **Build History**.

## Next

[Example 05 — Artifacts and Test Reports](../05-artifacts-and-test-reports/README.md)
