# 05 - Initial Jenkins Configuration

## Steps

1. Start Session Manager port forwarding to local port `8080`.
2. Open `http://localhost:8080`.
3. Unlock Jenkins using:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

1. Install the suggested plugins.
2. Create the first admin user.
3. Set the Jenkins URL carefully.

## Why It Matters

- the unlock step proves Jenkins installed correctly
- plugins shape what learners can demonstrate
- the Jenkins URL affects links, webhooks, and notifications

## Common Mistake

Setting a public URL before you know how learners will reach Jenkins.
