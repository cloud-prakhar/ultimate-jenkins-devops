# Local Agent

This image provides the Jenkins build worker for the local lab.

## Included Tools

- Java 21 runtime
- Git
- Docker CLI
- `curl`
- `jq`
- `unzip`
- basic troubleshooting tools such as `ping`, `ss`, `netstat`, `ps`, and `dig`

## Labels

- `linux`
- `docker`

## Workspace

The agent uses `/home/jenkins/agent` as its remote workspace root. Jenkins creates job workspaces under this path.

## How It Connects

1. Jenkins starts and loads the node definition from JCasC.
2. The agent container waits for Jenkins to become healthy.
3. The entrypoint fetches the JNLP secret from Jenkins using the local admin credentials.
4. The agent connects over WebSocket.

This keeps the learner workflow simple while still demonstrating the controller-agent model.
