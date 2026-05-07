#!/bin/bash
# Jenkins Backup Script
# Usage: bash backup-jenkins.sh [--s3-bucket BUCKET_NAME]
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────
JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/jenkins-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="jenkins-backup-${TIMESTAMP}"

# Parse args
S3_BUCKET=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --s3-bucket) S3_BUCKET="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── Colors ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Validate ──────────────────────────────────────────────────────────────
[ -d "${JENKINS_HOME}" ] || error "JENKINS_HOME not found: ${JENKINS_HOME}"

# ─── Create Backup ─────────────────────────────────────────────────────────
info "Starting backup: ${BACKUP_NAME}"
mkdir -p "${BACKUP_DIR}"

info "Creating archive (excluding workspaces and caches)..."
tar czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    --exclude="${JENKINS_HOME}/workspace" \
    --exclude="${JENKINS_HOME}/builds/*/archive" \
    --exclude="${JENKINS_HOME}/logs" \
    --exclude="${JENKINS_HOME}/caches" \
    --exclude="${JENKINS_HOME}/.m2" \
    --exclude="${JENKINS_HOME}/.npm" \
    "${JENKINS_HOME}" 2>&1 | tail -5

BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
info "Archive created: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"

# ─── Upload to S3 ──────────────────────────────────────────────────────────
if [ -n "${S3_BUCKET}" ]; then
    command -v aws >/dev/null 2>&1 || error "AWS CLI not found"
    info "Uploading to S3: s3://${S3_BUCKET}/jenkins-backups/${BACKUP_NAME}.tar.gz"
    aws s3 cp \
        "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
        "s3://${S3_BUCKET}/jenkins-backups/${BACKUP_NAME}.tar.gz" \
        --storage-class STANDARD_IA
    info "Upload complete"

    # Cleanup old S3 backups
    info "Cleaning up S3 backups older than ${RETENTION_DAYS} days..."
    CUTOFF_DATE=$(date -d "${RETENTION_DAYS} days ago" +%Y%m%d)
    aws s3 ls "s3://${S3_BUCKET}/jenkins-backups/" | \
        awk '{print $4}' | \
        grep "jenkins-backup-" | \
        while read -r file; do
            FILE_DATE=$(echo "$file" | grep -oP '\d{8}' || echo "00000000")
            if [[ "${FILE_DATE}" < "${CUTOFF_DATE}" ]]; then
                info "Deleting old backup: ${file}"
                aws s3 rm "s3://${S3_BUCKET}/jenkins-backups/${file}"
            fi
        done
fi

# ─── Cleanup Local ─────────────────────────────────────────────────────────
info "Cleaning local backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "jenkins-backup-*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete

# ─── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "   Backup Complete!"
echo "========================================="
echo "  Archive: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "  Size:    ${BACKUP_SIZE}"
[ -n "${S3_BUCKET}" ] && echo "  S3:      s3://${S3_BUCKET}/jenkins-backups/${BACKUP_NAME}.tar.gz"
echo ""
