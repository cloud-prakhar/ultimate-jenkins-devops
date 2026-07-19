# Example 14 — Tag-Based Release

Builds a release when a semver tag is pushed, and a snapshot the rest of the time.

- **Teaches:** tag discovery, `TAG_NAME`, `git describe`, semver validation, changelog generation between tags
- **Job type:** Multibranch Pipeline
- **Duration:** 10 minutes including setup
- **Cost:** none, runs against the lab's Gitea server

## Prerequisites

- [Example 12](../12-multibranch-and-pull-requests/README.md) completed — you need the `demo-app` repository, the `git-scm-creds` credential, and a working Multibranch job setup

## Step 1 — Commit The Jenkinsfile

```bash
cd demo-app
cp /path/to/examples/github-integration/14-tag-based-release/Jenkinsfile ./Jenkinsfile
git commit -am "Add release pipeline"
git push origin main
```

## Step 2 — Create The Multibranch Job With Tag Discovery

1. Click **New Item**, name it `example-14-release`, choose **Multibranch Pipeline**, click **OK**.
2. Under **Branch Sources**, click **Add source > Gitea**.
3. Set **Server**, **Owner**, **Repository** (`demo-app`), and **Credentials** (`git-scm-creds`) as in example 12.
4. Under **Behaviours**, click **Add** and select **Discover tags**.

   This step is the whole example. Without it Jenkins never builds tags, `TAG_NAME` is never set, and every release stage stays skipped.
5. Under **Scan Repository Triggers**, tick **Periodically if not otherwise run**, set **1 minute**.
6. Click **Save**.

## Step 3 — Build A Snapshot

Jenkins scans and builds `main`. Open that build's **Console Output**.

## Step 4 — Push A Tag And Build A Release

```bash
cd demo-app
git tag v1.0.0
git push origin v1.0.0
```

Then in Jenkins click **Scan Repository Now**. A **Tags** tab appears with `v1.0.0`.

Add a second release so the changelog has a range to work with:

```bash
echo "feature" >> README.md
git commit -am "Add a feature"
git push origin main
git tag v1.1.0
git push origin v1.1.0
```

Scan again and open the `v1.1.0` build.

## Expected Output

The `main` branch build produces a snapshot:

```text
Snapshot build: version=0.0.0-dev.1+abc1234
Not a tagged commit — publishing snapshot 0.0.0-dev.1+abc1234 instead of a release
Completed snapshot 0.0.0-dev.1+abc1234
```

The `v1.1.0` build produces a release:

```text
Release build: tag=v1.1.0 version=1.1.0
Tag format OK: v1.1.0
# v1.1.0

Changes since v1.0.0:
- Add a feature (Gitea Admin)

DRY RUN — would publish:
  docker tag  app:build registry:5000/app:1.1.0
  docker push registry:5000/app:1.1.0
  gh release create v1.1.0 --notes-file dist/CHANGELOG.md
Completed release 1.1.0
```

## Step 5 — Watch The Validation Reject A Bad Tag

```bash
git tag release-candidate-final-v2
git push origin release-candidate-final-v2
```

Scan again. That build fails at the **Validate Tag Format** stage:

```text
Tag 'release-candidate-final-v2' is not semver (expected v1.2.3 or 1.2.3-rc.1)
```

Failing here is the point. Catching a malformed tag before anything publishes is far cheaper than unpicking a bad release from a registry that other people have already pulled from.

Clean it up:

```bash
git tag -d release-candidate-final-v2
git push origin :refs/tags/release-candidate-final-v2
```

## Why Not Shallow

Example 11 used `shallow: true, depth: 1` for speed. This pipeline sets `shallow: false, noTags: false` instead, because `git describe` and the changelog range both need full history and all tags. A shallow clone silently breaks tag-based versioning — the build succeeds and produces the wrong version.

Speed and correctness genuinely trade off here. Shallow-clone your PR builds; full-clone your release builds.

## Tag The Commit, Not The Build

`BUILD_NUMBER` increments even when nothing changed, and resets if the job is recreated. A tag names a specific tree that anyone can check out and rebuild years later. Version from the tag; use the build number only for disambiguating snapshots.

## Running It Against Real GitHub

Swap the Gitea branch source for GitHub Branch Source, which has the same **Discover tags** behaviour. To actually create a GitHub Release, replace the dry-run block with a `gh release create` call wrapped in `withCredentials`, using a token with `repo` scope. `gh` is not installed on the lab agent — add it to `00-local-lab-setup/agent/Dockerfile`, or use `curl` against the REST API.

## What To Look At In The UI

- The job page shows separate **Branches** and **Tags** tabs once tag discovery is on.
- Tag builds never rebuild — a tag points at a fixed commit, so Jenkins builds it once. Rerun with **Build Now** on the tag sub-job if you need to.
- `dist/CHANGELOG.md` and `dist/VERSION` are archived on release builds. Open the artifacts on the `v1.1.0` build.

## Validation

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh github-integration/14-tag-based-release/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| No **Tags** tab | The **Discover tags** behaviour is missing. Add it in the branch source configuration and rescan. |
| `TAG_NAME` is null on a tag build | The job is not Multibranch, or tag discovery is off. The `git describe` fallback covers the first case. |
| `fatal: no tag exactly matches` | Normal on a branch build. The pipeline handles it and produces a snapshot version. |
| Changelog is empty | Only one tag exists, so there is no previous tag to diff against. Push a second one. |
| Version is `0.0.0-dev` on a tagged commit | The clone dropped tags. Confirm `shallow: false` and `noTags: false`. |
| `scm.branches` fails | That expression only works in a job that has an SCM definition — Multibranch or Pipeline-from-SCM, not a pasted script. |

## Cleanup

1. Open the Multibranch job, click **Delete Multibranch Pipeline**, confirm.
2. Remove the test tags:

```bash
cd demo-app
git push origin :refs/tags/v1.0.0 :refs/tags/v1.1.0
git tag -d v1.0.0 v1.1.0
```

## Next

[Example 15 — Commit Status and Checks](../15-commit-status-and-checks/README.md)
