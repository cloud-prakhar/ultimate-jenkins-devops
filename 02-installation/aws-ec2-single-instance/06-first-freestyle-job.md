# 06 - First Freestyle Job

Create a small freestyle job to prove the instance can run builds.

## Shell Step

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "Hello from Jenkins on EC2"
hostname
java -version
df -h
```

## Expected Result

- build succeeds
- console output shows hostname and disk space
