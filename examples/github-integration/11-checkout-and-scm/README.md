# Example 11 — Checkout and SCM

Clones a repository three different ways, reads commit metadata, and turns it into an image tag.

- **Teaches:** `checkout([$class: 'GitSCM'])`, GitSCM extensions, `checkout scm`, SCM credentials, deriving a version from a commit
- **Job type:** Pipeline
- **Duration:** 5 minutes including repository setup
- **Cost:** none, runs against the lab's Gitea server

## Prerequisites

- [Example 08](../../pipeline-scripts/08-credentials-and-secrets/README.md) completed — this example uses a credential
- Lab running, with Gitea reachable at `http://localhost:3000`

## Step 1 — Create A Test Repository In Gitea

1. Open `http://localhost:3000` and log in with `GITEA_ADMIN_USER` and `GITEA_ADMIN_PASSWORD` from your `00-local-lab-setup/.env`.
2. Click the **+** in the top right, then **New Repository**.
3. Name it `demo-app`.
4. Tick **Initialize Repository** so it has a `main` branch and at least one commit.
5. Click **Create Repository**.

Optionally add a few commits so the metadata stage has something to show — edit the README through the Gitea UI a couple of times.

## Step 2 — Add The Git Credential In Jenkins

1. **Manage Jenkins > Credentials > System > Global credentials > Add Credentials**.
2. **Kind**: Username with password.
3. **Username**: your `GITEA_ADMIN_USER`. **Password**: your `GITEA_ADMIN_PASSWORD`.
4. **ID**: `git-scm-creds` — this exact value, the Jenkinsfile references it.
5. Click **Create**.

## Step 3 — Run The Pipeline

1. Click **New Item**, name it `example-11-checkout`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now** to register the parameters.
4. Reload the job page, click **Build with Parameters**.
5. Confirm **GIT_URL** is `http://gitea:3000/<your-gitea-user>/demo-app.git` — adjust the username if yours differs. Use the hostname `gitea`, not `localhost`: the build runs inside the compose network.
6. Click **Build** and open **Console Output**.

## Expected Output

```text
Cloning repository http://gitea:3000/gitea-admin/demo-app.git
 > git init /home/jenkins/agent/workspace/example-11-checkout
Fetching upstream changes
 > git fetch --tags --force --progress --depth=1 -- http://gitea:3000/...
Checking out Revision abc1234... (refs/remotes/origin/main)

commit:  abc1234def5678...
short:   abc1234
branch:  HEAD
author:  Gitea Admin <admin@lab.local>
subject: Initial commit
Image tag would be: app:2-abc1234
```

`branch: HEAD` is expected. A shallow checkout of a specific revision leaves the repository in detached HEAD state — which is why the pipeline reads the branch from the job parameter rather than from git.

## Running It Against Real GitHub

Nothing in the Jenkinsfile is Gitea-specific. To point it at GitHub:

1. Change **GIT_URL** to `https://github.com/<owner>/<repo>.git`.
2. Replace the `git-scm-creds` credential with your GitHub username and a **personal access token** — GitHub has not accepted passwords over HTTPS since 2021. Generate one at **GitHub > Settings > Developer settings > Personal access tokens**, with the `repo` scope.
3. Rerun.

For a public repository you can clear the credential ID entirely.

## The Three Checkout Forms

| Form | When to use |
| --- | --- |
| `checkout scm` | Almost always, in a Multibranch or "Pipeline script from SCM" job. Jenkins already knows the repo, branch, and credentials — reuse them instead of duplicating them in code. |
| `checkout([$class: 'GitSCM', ...])` | Cloning a second repository, or when you need extensions. Used in this example because a script-pasted job has no `scm` to reuse. |
| `git url:, branch:, credentialsId:` | Demos only. It is a shorthand for the form above with no access to extensions. |

## Extensions Worth Knowing

| Extension | Effect |
| --- | --- |
| `CleanBeforeCheckout` | Discards local modifications first, so a poisoned workspace cannot affect the next build |
| `CloneOption(shallow: true, depth: 1)` | Much faster on large histories. Breaks `git describe` and tag-based versioning — see [example 14](../14-tag-based-release/README.md) |
| `CloneOption(noTags: false)` | Fetch tags. Required for any release pipeline |
| `SubmoduleOption` | Recurse into submodules |
| `LocalBranch` | Check out an actual branch instead of detached HEAD, when a build needs to commit back |

## What To Look At In The UI

- The build page shows a **Changes** section listing commits since the last build. Add a commit in Gitea and rerun to populate it.
- **Pipeline Syntax > Sample Step > checkout** generates the full `checkout([$class: 'GitSCM', ...])` block from a form, including the extensions. Faster and less error-prone than writing it by hand.
- **Git Build Data** on the build page shows the exact revision built.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh github-integration/11-checkout-and-scm/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Could not resolve host: gitea` | You used `localhost` in GIT_URL. The build runs in the compose network where the service is called `gitea`. |
| `Authentication failed` | Wrong credential, or the ID is not `git-scm-creds`. Check **Manage Jenkins > Credentials**. |
| `Couldn't find any revision to build` | The branch does not exist, or the repository was created without **Initialize Repository** and has no commits. |
| `fatal: not a git repository` in the metadata stage | The Checkout stage failed. Look above it in the console. |
| GitHub rejects your password | Use a personal access token, not your account password. |

## Cleanup

1. Open the job, click **Delete Pipeline**, confirm.
2. Delete the `git-scm-creds` credential if you are not continuing to example 12.
3. Leave the `demo-app` repository in Gitea — examples 12, 13, and 14 reuse it.

## Next

[Example 12 — Multibranch and Pull Requests](../12-multibranch-and-pull-requests/README.md)
