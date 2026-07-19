# Example 08 — Credentials and Secrets

Reads three kinds of credential from the Jenkins store, and demonstrates the ways people leak them by accident.

- **Teaches:** `withCredentials`, the `credentials()` helper, secret masking and its limits
- **Job type:** Pipeline
- **Duration:** 5 minutes including credential setup
- **Cost:** none, runs in the local lab

## Prerequisites

- [Example 02](../02-parameters-and-environment/README.md) completed
- The `credentials-binding` plugin — preinstalled in the lab

## Step 1 — Create The Credentials

The pipeline expects three credentials to exist. Create them first, or the build fails at the first `withCredentials` block.

1. From the Jenkins home page, click **Manage Jenkins**.
2. Click **Credentials** under Security.
3. Click **System**, then **Global credentials (unrestricted)**.
4. Click **Add Credentials** and create each of these:

| Kind | ID | Fields |
| --- | --- | --- |
| Secret text | `demo-api-token` | **Secret**: any string, for example `demo-token-abc123` |
| Username with password | `demo-registry-creds` | **Username**: `demo-user`, **Password**: any string |
| Secret file | `demo-kubeconfig` | **File**: upload any small text file |

The **ID** field is what the Jenkinsfile references. Set it explicitly — if you leave it blank Jenkins generates a UUID, and the pipeline will not find the credential.

Leave **Scope** as **Global**. In production, scope credentials to the narrowest folder that needs them; see [12-security](../../../12-security/README.md).

## Step 2 — Run The Pipeline

1. Click **New Item**, name it `example-08-credentials`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now**.
4. Open the build's **Console Output**.

## Expected Output

Secrets appear as `****` everywhere they would otherwise print:

```text
+ echo 'token is: ****'
token is: ****
+ echo 'logging in as demo-user'
logging in as demo-user
+ echo 'registry pass: ****'
registry pass: ****
kubeconfig staged at a temporary path
```

The username is *not* masked. Only the secret half of a username/password credential is. Treat usernames as public.

## What To Look At In The UI

- **Manage Jenkins > Credentials** — each credential shows its ID and description but never its value. Once saved, a secret cannot be read back through the UI, only replaced.
- The build page shows no credential information. Jenkins deliberately does not record which credentials a build used in the UI.
- Try **Pipeline Syntax** (linked at the bottom of any Pipeline job's configuration page): choose `withCredentials` from the sample step dropdown, pick a credential, and click **Generate Pipeline Script**. It writes the binding block for you, with the right ID.

## The Three Credential Types

| Type | Binding | Produces |
| --- | --- | --- |
| Secret text | `string(credentialsId:, variable:)` | One environment variable |
| Username with password | `usernamePassword(credentialsId:, usernameVariable:, passwordVariable:)` | Two environment variables |
| Secret file | `file(credentialsId:, variable:)` | A path to a temporary file, deleted when the block exits |

The `environment { X = credentials('id') }` shorthand on a username/password credential creates three variables: `X`, `X_USR`, and `X_PSW`. Convenient, but it puts the secret in scope for the whole pipeline rather than one block. Prefer `withCredentials` when the secret is only needed in one stage.

## Quoting Matters

```groovy
sh 'echo $API_TOKEN'   // correct — the SHELL expands it at runtime
sh "echo $API_TOKEN"   // wrong — GROOVY interpolates it into the command string
```

With double quotes, the literal secret becomes part of the shell command. It can then show up in `ps` output, in shell tracing, and in error messages that masking does not cover. Jenkins warns about this in the console when it detects it.

## Masking Is A Safety Net, Not A Boundary

Jenkins masks exact string matches in the log. Transform the secret and it passes straight through:

```bash
echo $API_TOKEN | base64   # leaks
echo $API_TOKEN | rev      # leaks
```

Writing a secret into an archived artifact, or into a file that a later stage prints, leaks it too. The defense is not to rely on masking: never print secrets, never archive them, and rotate anything that reaches a build log.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/08-credentials-and-secrets/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Could not find credentials entry with ID 'demo-api-token'` | The credential does not exist, or its ID differs. Check **Manage Jenkins > Credentials** and set the ID field explicitly. |
| `CredentialNotFoundException` on a folder-scoped credential | Credential scope does not cover the job. Move it to Global, or to a folder containing the job. |
| Secret prints in clear text | You used double quotes in the `sh` step, or transformed the value. See above. |
| `docker login` fails | Expected — the lab registry is unauthenticated. The shell fallback after it keeps the stage green. |

## Cleanup

1. Open the job, click **Delete Pipeline**, confirm.
2. Go to **Manage Jenkins > Credentials > System > Global credentials**, and delete `demo-api-token`, `demo-registry-creds`, and `demo-kubeconfig`.

## Next

[Example 09 — Error Handling and Retries](../09-error-handling-and-retries/README.md)
