#!/usr/bin/env bash
#
# Validate example Jenkinsfiles against a running Jenkins.
#
# Posts each file to Jenkins' declarative linter endpoint and reports pass,
# fail, or skip. Scripted pipelines cannot be linted this way and are skipped.
#
# Usage:
#   export JENKINS_URL=http://localhost:8080
#   export JENKINS_USER=admin
#   export JENKINS_TOKEN='<api-token-or-password>'
#   ./examples/validate-examples.sh                 # all examples
#   ./examples/validate-examples.sh path/to/Jenkinsfile [...]
#
# Generate an API token at:
#   Jenkins > your username > Configure > API Token > Add new Token

set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-}"
JENKINS_TOKEN="${JENKINS_TOKEN:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$JENKINS_USER" ] || [ -z "$JENKINS_TOKEN" ]; then
    echo "ERROR: set JENKINS_USER and JENKINS_TOKEN before running." >&2
    echo "  export JENKINS_USER=admin" >&2
    echo "  export JENKINS_TOKEN='<api-token>'" >&2
    exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: required command not found: curl" >&2
    exit 2
fi

# Jenkins requires a CSRF crumb on POST. Fetch one, and reuse the session
# cookie so the crumb stays valid for every subsequent request.
COOKIE_JAR="$(mktemp)"
trap 'rm -f "$COOKIE_JAR"' EXIT

echo "Connecting to ${JENKINS_URL} as ${JENKINS_USER}"

CRUMB_RESPONSE="$(
    curl -sS --fail-with-body \
        --user "${JENKINS_USER}:${JENKINS_TOKEN}" \
        --cookie-jar "$COOKIE_JAR" \
        "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" \
        2>&1
)" || {
    echo "ERROR: could not fetch a CSRF crumb from ${JENKINS_URL}" >&2
    echo "       Is Jenkins running, and are the credentials correct?" >&2
    echo "$CRUMB_RESPONSE" >&2
    exit 2
}

# Collect the files to check.
if [ "$#" -gt 0 ]; then
    FILES=("$@")
else
    # shellcheck disable=SC2312 # find failures surface via the empty-array check below
    mapfile -t FILES < <(find "$SCRIPT_DIR" -name Jenkinsfile -type f | sort)
fi

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "No Jenkinsfile found to validate." >&2
    exit 2
fi

PASSED=0
FAILED=0
SKIPPED=0

for file in "${FILES[@]}"; do
    label="${file#"${SCRIPT_DIR}/"}"

    if [ ! -f "$file" ]; then
        printf '  SKIP  %s (not found)\n' "$label"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # The declarative linter only understands "pipeline { }". A scripted
    # pipeline starts with node { } and would always be reported invalid.
    if ! grep -qE '^\s*pipeline\s*\{' "$file"; then
        printf '  SKIP  %s (scripted pipeline, not lintable)\n' "$label"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    result="$(
        curl -sS \
            --user "${JENKINS_USER}:${JENKINS_TOKEN}" \
            --cookie "$COOKIE_JAR" \
            --cookie-jar "$COOKIE_JAR" \
            -H "$CRUMB_RESPONSE" \
            -F "jenkinsfile=<${file}" \
            "${JENKINS_URL}/pipeline-model-converter/validate" 2>&1
    )" || result="request failed: $result"

    if printf '%s' "$result" | grep -q 'successfully validated'; then
        printf '  PASS  %s\n' "$label"
        PASSED=$((PASSED + 1))
    else
        printf '  FAIL  %s\n' "$label"
        printf '%s\n' "$result" | sed 's/^/          /'
        FAILED=$((FAILED + 1))
    fi
done

echo
echo "Passed: ${PASSED}  Failed: ${FAILED}  Skipped: ${SKIPPED}"

[ "$FAILED" -eq 0 ]
