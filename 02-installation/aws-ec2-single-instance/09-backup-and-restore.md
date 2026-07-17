# 09 - Backup and Restore

## What Lives in JENKINS_HOME

- job definitions
- build history
- plugins
- credentials store
- secrets used to encrypt credentials

## Backup Strategy

- file-level backup for `JENKINS_HOME`
- EBS snapshots for instance-level recovery
- plugin compatibility checks before restore

## Commands

```bash
./scripts/backup-jenkins.sh
./scripts/restore-jenkins.sh /path/to/archive.tar.gz
```

## Validate After Restore

```bash
sudo systemctl status jenkins --no-pager
curl -I http://localhost:8080/login
```
