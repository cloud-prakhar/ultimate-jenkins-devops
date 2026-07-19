# Example 10 — Scripted Multi-Stage

The same pipeline shape as examples 01-06, written in scripted syntax, plus the one thing scripted does that declarative cannot: generate stages at runtime.

- **Teaches:** `node {}`, dynamic parallel stages, `try`/`catch`/`finally` in place of `post`, closure capture
- **Job type:** Pipeline
- **Duration:** 2 minutes
- **Cost:** none, runs in the local lab
- **Pairs with:** [07-scripted-pipelines](../../../07-scripted-pipelines/README.md)

## Prerequisites

- [Example 03](../03-parallel-stages/README.md) and [Example 06](../06-post-conditions-and-notifications/README.md) completed — this example is best read as a comparison against them

## Jenkins UI Steps

1. Click **New Item**, name it `example-10-scripted`, choose **Pipeline**, click **OK**.
2. Scroll to **Pipeline**, paste [`Jenkinsfile`](./Jenkinsfile) into the **Script** box.
3. Click **Save**, then **Build Now**.
4. Open **Console Output**.
5. Compare the **Stage View** against example 03's. Scripted stages render the same way; Jenkins does not care which syntax produced them.

## Expected Output

```text
Build #1 on local-linux-agent
+ echo 'artifact 1' 
[test-auth] testing module auth
[test-billing] testing module billing
[test-search] testing module search
[test-auth] auth ok
[test-billing] billing ok
[test-search] search ok
Skipping deploy on branch: unknown
Archiving artifacts
Result: SUCCESS
Finished: SUCCESS
```

`Skipping deploy on branch: unknown` is correct — `env.BRANCH_NAME` is null in a plain Pipeline job. The `?:` operator supplies the fallback.

## Declarative vs Scripted

| | Declarative | Scripted |
| --- | --- | --- |
| Entry point | `pipeline { }` | `node { }` |
| Validated before running | Yes | No — errors surface mid-build |
| Options | `options { }` block | Wrap the body: `timeout { timestamps { } }` |
| Conditionals | `when { }` | Plain `if` |
| Cleanup and notification | `post { }` | `try`/`catch`/`finally` |
| Blue Ocean rendering | Full | Partial |
| Dynamic stages | Not possible | The main reason to use it |

**Use declarative by default.** It catches syntax errors before consuming an executor, reviews better, and covers what most pipelines need. Reach for scripted when you genuinely need to compute the pipeline shape at runtime.

You can also keep declarative and drop into Groovy for the parts that need it, using a `script { }` block inside a stage — example 09 does exactly that. That is usually the better answer than converting a whole pipeline to scripted.

## The Closure Capture Trap

The dynamic stage loop contains a line that looks redundant:

```groovy
for (m in modules) {
    def name = m          // capture the loop variable
    branches["test-${name}"] = { echo "testing module ${name}" }
}
```

Without `def name = m`, all three closures reference the same variable `m`, and by the time they execute the loop has finished — so every branch reports `search`. This bites everyone once. The `def` inside the loop body creates a new binding per iteration.

## What To Look At In The UI

- **Console Output** shows the three parallel branches prefixed with their generated names. Those names came from a list in the code, not from the Jenkinsfile's structure.
- **Stage View** includes a **Cleanup** stage even on a failed build, because it is inside `finally`. Change the Build stage to `sh 'exit 1'` and rerun to confirm.
- **Blue Ocean** renders scripted pipelines less richly than declarative ones. Compare against example 03 — this is a real cost of choosing scripted.

## Validation

The declarative linter cannot validate scripted pipelines, so this example is reported as **skipped** by the validation script. That is expected, and is itself the argument for declarative: there is no pre-flight check available here.

```bash
export JENKINS_URL=http://localhost:8080 JENKINS_USER=admin JENKINS_TOKEN='<token>'
../../validate-examples.sh pipeline-scripts/10-scripted-multistage/Jenkinsfile
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| All three branches report the same module | The closure capture trap. Keep `def name = m` inside the loop. |
| `Scripts not permitted to use method ...` | Groovy sandbox restriction. Approve it under **Manage Jenkins > In-process Script Approval**, or avoid the method. Declarative hits this less often. |
| `java.lang.NoSuchMethodError: No such DSL method 'pipeline'` | You pasted a declarative pipeline into a job expecting this one, or mixed the two syntaxes. They cannot be combined at the top level. |
| No cleanup on failure | Confirm the `finally` block is attached to the outer `try`, not to an inner stage. |

## Cleanup

Open the job, click **Delete Pipeline**, confirm.

## Next

[Example 11 — Checkout and SCM](../../github-integration/11-checkout-and-scm/README.md), the first of the SCM integration set.
