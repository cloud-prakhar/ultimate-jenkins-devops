# Example 07 — Docker Agents Per Stage

Runs each stage in a different container, so a pipeline can use Python and Node without either being installed on the agent.

- **Teaches:** `agent none`, per-stage `docker` agents, building an image inside a pipeline, and the Docker socket trade-off
- **Job type:** Pipeline
- **Duration:** 5 minutes on the first run while images pull, under 1 minute after
- **Cost:** none, but pulls about 200 MB of images the first time

## Prerequisites

- [Example 01](../01-hello-multistage/README.md) completed
- Lab running, with internet access for the first image pull
- The `docker-workflow` plugin — preinstalled in the lab

## Jenkins UI Steps

1. Click **New Item**, name it `example-07-docker-agents`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now**.
4. Open the build's **Console Output** immediately — the first run shows the image pulls in real time.
5. When it finishes, check the **Stage View** on the job page. Each stage reports its own duration; the two container stages are noticeably slower on the first run.
6. Confirm the images landed on the host:

```bash
docker images | grep -E 'python|node|alpine'
```

## Expected Output

```text
[Pipeline] { (Python Checks)
Unable to find image 'python:3.12-slim' locally
3.12-slim: Pulling from library/python
...
+ python --version
Python 3.12.x
python stage ok

[Pipeline] { (Node Checks)
+ node --version
v20.x.x
node stage ok

[Pipeline] { (Build Image)
+ docker build -f Dockerfile.demo -t demo-app:1 .
...
Successfully tagged demo-app:1
+ docker run --rm demo-app:1
demo image
```

## What To Look At In The UI

- **Console Output** shows the full `docker run` command Jenkins generates for each container stage, including the workspace bind mount and the `-u` flag matching the agent's user. Reading it once explains most "permission denied" problems you will hit later.
- **Stage View** durations on the first build versus the second make the image pull cost obvious. This is the argument for warming caches on your agents.
- **Manage Jenkins > Nodes > local-linux-agent** — every stage still runs on the same agent. The containers are started *by* the agent, not instead of it.

## Why `agent none`

Declaring `agent none` at the top forces every stage to state where it runs. Without it, a `pipeline { agent any }` plus per-stage agents means any stage you forget to annotate silently runs on whatever is free — often the wrong toolchain, occasionally the controller.

## The Docker Socket Trade-Off

`00-local-lab-setup/docker-compose.yml` mounts `/var/run/docker.sock` into the agent container. That is what lets a build run `docker build`.

It also grants the build effective root on the host. Any pipeline that can run a shell step can start a privileged container and mount the host filesystem. In a local throwaway lab that is a reasonable shortcut. On a shared Jenkins where anyone can commit a Jenkinsfile, it is a full compromise path.

Production alternatives:

- **Kubernetes agents** — one pod per build, no shared daemon. See [`templates/Jenkinsfile.kubernetes-agent`](../../../templates/Jenkinsfile.kubernetes-agent) and [10-kubernetes-integration](../../../10-kubernetes-integration/README.md).
- **Rootless builders** — Kaniko, Buildah, or BuildKit in rootless mode build images without a privileged daemon.
- **A dedicated build service** — push the build to something outside Jenkins entirely.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/07-docker-agents/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `docker: command not found` | The stage is not on the `linux` agent. Container stages need `label 'linux'` inside the `docker { }` block. |
| `permission denied while trying to connect to the Docker daemon socket` | The socket mount is missing or the agent user cannot read it. Check the `volumes:` entry for the agent in `docker-compose.yml`. |
| `Cannot connect to the Docker daemon` | Docker is not running on your host. Start Docker Desktop or `sudo systemctl start docker`. |
| Image pull times out | No internet, or a proxy. Pre-pull with `docker pull python:3.12-slim` on the host — the agent shares the host daemon, so it will find it locally. |
| Workspace files missing inside the container | Jenkins bind-mounts the workspace automatically; a custom `args` string that overrides `-v` can break it. |

## Cleanup

Open the job, click **Delete Pipeline**, confirm. Then reclaim the pulled images:

```bash
docker image prune -f
docker rmi python:3.12-slim node:20-alpine alpine:3.20
```

## Next

[Example 08 — Credentials and Secrets](../08-credentials-and-secrets/README.md)
