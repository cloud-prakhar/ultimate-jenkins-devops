# 11 - Troubleshooting

## Common Problems

| Problem | Symptom | Fix |
| --- | --- | --- |
| Session Manager not connected | instance missing from SSM | verify IAM role and outbound internet access |
| Jenkins not starting | `systemctl status` failed | check Java install and `journalctl -u jenkins` |
| Port forward works but page fails | HTTP timeout | verify local service on `localhost:8080` in the instance |
| Disk too small | plugin installs fail or builds stop | resize EBS and clean old build data |

## Validation

```bash
./scripts/verify-instance.sh
./scripts/verify-jenkins.sh
```
