# 04 - Installing Jenkins

## Technical Explanation

Jenkins requires Java. This lab uses Java 21 and Jenkins LTS from the official package repository.

## Simple Explanation

Install Java first, then install Jenkins, then start the service.

## Commands on the Instance

```bash
sudo bash /opt/ultimate-jenkins/install-jenkins.sh
sudo systemctl status jenkins --no-pager
java -version
curl -I http://localhost:8080/login
```

## Expected Output

- Jenkins service is `active (running)`
- `curl` returns HTTP `200` or `403`
- `/var/lib/jenkins/secrets/initialAdminPassword` exists
