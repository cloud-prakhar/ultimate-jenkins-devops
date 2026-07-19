# Example 02 — Parameters and Environment

Makes a pipeline configurable at build time, and shows the difference between `params`, global `environment`, and stage-scoped `environment`.

- **Teaches:** `parameters`, `environment`, `params.X` vs `env.X`, stage-scoped variables
- **Job type:** Pipeline
- **Duration:** 2 minutes
- **Cost:** none, runs in the local lab

## Prerequisites

- [Example 01](../01-hello-multistage/README.md) completed
- Lab running

## Jenkins UI Steps

1. Click **New Item**, name it `example-02-parameters`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, keep **Definition** as **Pipeline script**.
3. Paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
4. Click **Save**.
5. Click **Build Now**. Note that the sidebar says **Build Now**, not **Build with Parameters** — the parameters are not registered yet.
6. Let build **#1** finish, then reload the job page.
7. The sidebar now shows **Build with Parameters**. Click it.
8. Set **APP_NAME** to `payments-api`, **ENVIRONMENT** to `staging`, and tick **VERBOSE**.
9. Click **Build**.
10. Open build **#2 > Console Output**.

Step 5 is the point of the example. Jenkins learns a job's parameters by executing the pipeline once; a fresh parameterized job never offers parameters on its first build.

## Expected Output

Build #2 console output includes:

```text
APP_NAME    = payments-api
ENVIRONMENT = staging
VERBOSE     = true (type: Boolean)
BUILD_LABEL = payments-api-staging-2
STAGE_NOTE inside stage: set for this stage only
```

Because **VERBOSE** was ticked, the **Diagnostics** stage also runs and prints `git version`, `Docker version`, and a workspace listing. In build #1 that stage was skipped.

## What To Look At In The UI

- **Stage View** shows **Diagnostics** as a grey "skipped" cell for build #1 and a green cell for build #2. Skipped stages are not failures.
- **Build with Parameters** renders each parameter by type: a text box for `string`, a dropdown for `choice`, a checkbox for `booleanParam`.
- The build page shows a **Parameters** link listing exactly what this build ran with — the audit trail for "why did that deploy go to staging?"

## Key Distinction

| Expression | What it is |
| --- | --- |
| `params.VERBOSE` | The typed parameter — a real Boolean, safe in `if` and `when` |
| `env.VERBOSE` | The same value as a string — `"true"`, which is truthy even when it reads `"false"` |
| `${env.BUILD_LABEL}` | Global `environment` entry, resolved once when the pipeline starts |
| `${STAGE_NOTE}` | Stage-scoped, undefined outside its stage |

Comparing `env.VERBOSE == 'true'` works; treating `env.VERBOSE` as a boolean does not. Use `params` for parameters.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/02-parameters-and-environment/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| **Build with Parameters** never appears | Run the job once first, then reload the page. |
| `STAGE_NOTE: unbound variable` | You moved the `sh` step outside the stage that defines it. Stage-scoped variables do not leak. |
| Diagnostics runs when VERBOSE is unticked | You used `env.VERBOSE` instead of `params.VERBOSE` in the `when` block. |

## Cleanup

Open the job, click **Delete Pipeline**, confirm.

## Next

[Example 03 — Parallel Stages](../03-parallel-stages/README.md)
