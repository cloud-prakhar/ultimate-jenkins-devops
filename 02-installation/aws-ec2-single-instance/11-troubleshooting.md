# 11 - Troubleshooting

## Common Problems

| Problem | Symptom | Fix |
| --- | --- | --- |
| Session Manager not connected | instance missing from SSM | verify IAM role and outbound internet access |
| Jenkins never installed | `Unit jenkins.service could not be found` | the user data script aborted; read `/var/log/cloud-init-output.log`, then re-run `sudo bash /opt/ultimate-jenkins/install-jenkins.sh`. Full walkthrough in [04-installing-jenkins.md](./04-installing-jenkins.md) Step 2 |
| Expired Jenkins signing key | `NO_PUBKEY` / `repository is not signed` | the widely-copied `jenkins.io-2023.key` **expired 2026-03-26**; use `jenkins.io-2026.key`. The scripts in this repo auto-detect the current key |
| Stale broken apt repo | `apt update` still fails after fixing the key | a failed run left `/etc/apt/sources.list.d/jenkins.list` behind; `sudo rm -f /etc/apt/sources.list.d/jenkins.list /usr/share/keyrings/jenkins-keyring.asc` then re-run |
| Instance type rejected | `not eligible for Free Tier` | new AWS Free Tier accounts block non-eligible types; use `c7i-flex.large` (4 GB) or `m7i-flex.large` (8 GB) |
| Jenkins not starting | `systemctl status` shows failed/activating | check Java install, memory (`free -m`, needs 4 GB), and `journalctl -u jenkins` |
| `curl` returns 403 | looks like an error | not an error — Jenkins is up and asking for auth |
| Port forward works but page fails | HTTP timeout | verify local service on `localhost:8080` in the instance |
| Disk too small | plugin installs fail or builds stop | resize EBS and clean old build data |

## Validation

```bash
./scripts/verify-instance.sh
./scripts/verify-jenkins.sh
```
