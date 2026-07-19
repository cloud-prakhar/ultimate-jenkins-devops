# Example 01 — Hello Multi-Stage

The smallest useful declarative pipeline: four stages, an artifact, and a cleanup block. Every other example builds on this skeleton.

- **Teaches:** `agent`, `options`, `stages`, `post`, `archiveArtifacts`
- **Job type:** Pipeline
- **Duration:** 1 minute
- **Cost:** none, runs in the local lab

## Prerequisites

- Lab running: `cd 00-local-lab-setup && ./scripts/verify-lab.sh`
- Jenkins reachable at `http://localhost:8080`

## Jenkins UI Steps

1. Open `http://localhost:8080` and log in.
2. Click **New Item** in the left sidebar.
3. Enter the name `example-01-hello-multistage`.
4. Select **Pipeline** and click **OK**.
5. On the configuration page, scroll to the **Pipeline** section at the bottom.
6. Leave **Definition** set to **Pipeline script**.
7. Open [`Jenkinsfile`](./Jenkinsfile) from this folder, copy all of it, and paste it into the **Script** box.
8. Click **Save**.
9. Click **Build Now** in the left sidebar.
10. Under **Build History**, click build **#1**.
11. Click **Console Output**.

## Expected Output

The console output ends with:

```text
[Pipeline] { (Package)
+ tar -czf build/app-1.tar.gz -C build app.txt
Archiving artifacts
Archived app-1.tar.gz
Finished: SUCCESS
```

Every line carries a timestamp prefix because of `timestamps()`.

## What To Look At In The UI

- **Stage View** on the job page shows four columns — Prepare, Build, Test, Package — with a duration each. Run the job two or three times to see the trend build up.
- **Last Successful Artifacts** on the build page lists `app-1.tar.gz`. Click it to download.
- **Manage Jenkins > Nodes** confirms the build ran on the agent, not the controller. The build page header says `Running as SYSTEM on local-linux-agent`.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/01-hello-multistage/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Build stuck in the queue | No agent matches `linux`. Check **Manage Jenkins > Nodes**, then `docker compose ps agent` in `00-local-lab-setup`. |
| `tar: build: Cannot open` | The Prepare stage did not run. Confirm you pasted the whole file, starting at `pipeline {`. |
| No artifact listed | The Package stage failed. Read the console output above the failure. |

## Cleanup

1. Open the job.
2. Click **Delete Pipeline** in the left sidebar.
3. Confirm.

## Next

[Example 02 — Parameters and Environment](../02-parameters-and-environment/README.md)
