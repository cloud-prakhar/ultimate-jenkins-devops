# Example 05 — Artifacts and Test Reports

Publishes a JUnit test report, an HTML coverage report, and a build artifact — the three things that turn a green checkmark into evidence.

- **Teaches:** `junit`, `archiveArtifacts`, `publishHTML`, fingerprints, UNSTABLE vs FAILURE
- **Job type:** Pipeline
- **Duration:** 2 minutes
- **Cost:** none, runs in the local lab

## Prerequisites

- [Example 01](../01-hello-multistage/README.md) completed
- Lab running — the `junit`, `htmlpublisher`, and `ws-cleanup` plugins are preinstalled

## Jenkins UI Steps

1. Click **New Item**, name it `example-05-reports`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now**.
4. Run it **three or four times** so the test trend graph has data to plot.
5. On the job page, click **Test Result Trend** — the graph appears after the second build.
6. Open the latest build and click **Test Result**.
7. Click the failing test `demo.MathTest.divides_numbers` to see its failure message.
8. Back on the build page, click **Coverage Report** in the left sidebar.
9. Click `app-N.tar.gz` under **Build Artifacts** to download it.

## Expected Output

The build finishes **UNSTABLE**, shown as a yellow ball rather than a red one:

```text
[Pipeline] junit
Recording test results
[Checks API] No suitable checks publisher found.
Build step 'Publish JUnit test result report' changed build result to UNSTABLE
...
Finished: UNSTABLE
```

The `No suitable checks publisher found` line is normal — the lab has no Checks API plugin, and the JUnit results still publish. [Example 15](../../github-integration/15-commit-status-and-checks/README.md) covers that plugin.

The **Test Result** page reports 3 tests, 1 failure.

## UNSTABLE vs FAILURE

This distinction matters more than it first looks:

| Result | Color | Means | Typical cause |
| --- | --- | --- | --- |
| SUCCESS | Blue or green | Everything passed | — |
| UNSTABLE | Yellow | The build worked, the code did not | Failing tests, quality gate breach |
| FAILURE | Red | The build itself broke | Compile error, missing dependency, bad script |

Downstream jobs and `post` blocks can react to these differently — you might deploy on SUCCESS, notify on UNSTABLE, and page someone on FAILURE. Collapsing failing tests into FAILURE throws that signal away.

## What To Look At In The UI

- **Test Result Trend** on the job page — a stacked graph of passing and failing counts per build. This is why `junit` belongs in a `post { always { } }` block: a stage that fails before publishing leaves a hole in the trend.
- **Test Result > History** shows how long an individual test has been failing.
- **Build Artifacts** with a fingerprint link next to each file. Click **fingerprint** to see every build and job that used that exact file — the answer to "which build produced the binary in production?".

## The HTML Report Caveat

Jenkins applies a strict Content-Security-Policy to published HTML, so reports with inline CSS or JavaScript render unstyled. The simple report here is readable regardless.

Lab-only workaround, via **Manage Jenkins > Script Console**:

```groovy
System.setProperty("hudson.model.DirectoryBrowserSupport.CSP",
    "sandbox allow-scripts; default-src 'self'; style-src 'self' 'unsafe-inline';")
```

This resets when Jenkins restarts. Do not relax CSP on a shared or internet-facing Jenkins — published HTML is attacker-controlled content if anyone can run a build.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/05-artifacts-and-test-reports/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `No test report files were found` | The Test stage failed before writing the XML. `allowEmptyResults: false` makes this fail loudly on purpose. |
| Build is FAILURE, not UNSTABLE | Something other than the test assertion broke. Read the console output above the failure. |
| Coverage Report link missing | The `publishHTML` step did not run. Check the Coverage Report stage in the console output. |
| Report renders as plain text | CSP. See the workaround above. |
| Artifacts vanish from old builds | `artifactNumToKeepStr: '5'` keeps artifacts for the last 5 builds while retaining 10 build records. Intentional. |

## Cleanup

Open the job, click **Delete Pipeline**, confirm. Archived artifacts are deleted with the job.

## Next

[Example 06 — Post Conditions and Notifications](../06-post-conditions-and-notifications/README.md)
