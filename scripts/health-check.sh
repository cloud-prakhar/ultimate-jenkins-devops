#!/bin/bash
# Jenkins Health Check Script
# Usage: bash health-check.sh [JENKINS_URL] [USER] [TOKEN]
set -euo pipefail

JENKINS_URL="${1:-http://localhost:8080}"
JENKINS_USER="${2:-admin}"
JENKINS_TOKEN="${3:-${JENKINS_TOKEN:-}}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass()    { echo -e "${GREEN}[PASS]${NC} $*"; }
fail()    { echo -e "${RED}[FAIL]${NC} $*"; FAILURES=$((FAILURES+1)); }
warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }

FAILURES=0

echo "==================================="
echo "  Jenkins Health Check"
echo "  URL: ${JENKINS_URL}"
echo "==================================="
echo ""

# 1. API Response
echo "--- Connectivity ---"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    "${JENKINS_URL}/api/json" \
    ${JENKINS_TOKEN:+--user "${JENKINS_USER}:${JENKINS_TOKEN}"})

if [ "${STATUS}" = "200" ]; then
    JENKINS_VERSION=$(curl -s -I "${JENKINS_URL}" | grep -i "X-Jenkins:" | tr -d '\r' | awk '{print $2}')
    pass "Jenkins API responding (version: ${JENKINS_VERSION})"
elif [ "${STATUS}" = "403" ]; then
    warning "Jenkins API requires authentication (status: ${STATUS})"
else
    fail "Jenkins API not responding (status: ${STATUS})"
fi

# 2. Queue
if [ -n "${JENKINS_TOKEN}" ]; then
    echo ""
    echo "--- Build Queue ---"
    QUEUE_LENGTH=$(curl -s "${JENKINS_URL}/queue/api/json" \
        --user "${JENKINS_USER}:${JENKINS_TOKEN}" | \
        python3 -c "import sys,json; print(len(json.load(sys.stdin)['items']))" 2>/dev/null || echo "N/A")

    if [ "${QUEUE_LENGTH}" = "N/A" ]; then
        warning "Could not retrieve queue info"
    elif [ "${QUEUE_LENGTH}" -gt 50 ]; then
        fail "Queue length is ${QUEUE_LENGTH} (threshold: 50)"
    elif [ "${QUEUE_LENGTH}" -gt 20 ]; then
        warning "Queue length is ${QUEUE_LENGTH} (consider adding agents)"
    else
        pass "Queue length: ${QUEUE_LENGTH}"
    fi

    # 3. Executors
    echo ""
    echo "--- Executors ---"
    EXEC_DATA=$(curl -s "${JENKINS_URL}/computer/api/json" \
        --user "${JENKINS_USER}:${JENKINS_TOKEN}" 2>/dev/null)

    if [ -n "${EXEC_DATA}" ]; then
        TOTAL=$(echo "${EXEC_DATA}" | python3 -c "import sys,json; print(json.load(sys.stdin)['totalExecutors'])")
        BUSY=$(echo "${EXEC_DATA}" | python3 -c "import sys,json; print(json.load(sys.stdin)['busyExecutors'])")
        FREE=$((TOTAL - BUSY))

        if [ "${TOTAL}" -eq 0 ]; then
            warning "No executors configured (check agent connections)"
        else
            UTIL=$((BUSY * 100 / TOTAL))
            if [ "${UTIL}" -gt 90 ]; then
                warning "Executor utilization: ${UTIL}% (${BUSY}/${TOTAL})"
            else
                pass "Executor utilization: ${UTIL}% (${BUSY}/${TOTAL}, ${FREE} free)"
            fi
        fi
    fi

    # 4. Offline Agents
    OFFLINE=$(echo "${EXEC_DATA}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
offline = [c['displayName'] for c in data.get('computer', []) if c.get('offline', False)]
print(len(offline))
for name in offline: print(f'  - {name}')
" 2>/dev/null | head -1 || echo "0")

    if [ "${OFFLINE}" -gt 0 ]; then
        fail "${OFFLINE} agent(s) offline"
    else
        pass "All agents online"
    fi
fi

# 5. Disk Space
echo ""
echo "--- Disk Space ---"
if [ -d "/var/jenkins_home" ]; then
    DISK_USAGE=$(df -h /var/jenkins_home | tail -1 | awk '{print $5}' | tr -d '%')
    if [ "${DISK_USAGE}" -gt 90 ]; then
        fail "Disk usage: ${DISK_USAGE}% (critical)"
    elif [ "${DISK_USAGE}" -gt 80 ]; then
        warning "Disk usage: ${DISK_USAGE}% (warning)"
    else
        pass "Disk usage: ${DISK_USAGE}%"
    fi
elif command -v kubectl >/dev/null 2>&1; then
    warning "Cannot check disk (container environment)"
fi

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "==================================="
if [ "${FAILURES}" -eq 0 ]; then
    echo -e "${GREEN}  All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}  ${FAILURES} check(s) failed!${NC}"
    exit 1
fi
