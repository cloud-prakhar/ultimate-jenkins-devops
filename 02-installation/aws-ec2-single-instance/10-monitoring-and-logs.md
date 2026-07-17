# 10 - Monitoring and Logs

## Logs to Check

```bash
sudo journalctl -u jenkins -n 100 --no-pager
sudo tail -n 100 /var/log/cloud-init-output.log
df -h
free -m
```

## Why It Matters

- service logs show startup failures
- cloud-init logs show provisioning errors
- disk and memory pressure are common Jenkins problems
