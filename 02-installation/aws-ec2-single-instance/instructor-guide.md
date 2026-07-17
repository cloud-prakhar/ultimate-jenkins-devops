# Instructor Guide

## 90-Minute Session

| Time | Activity |
| ---: | --- |
| 10 minutes | Architecture and prerequisites |
| 15 minutes | Launch EC2 |
| 15 minutes | Install Java and Jenkins |
| 10 minutes | Initial Jenkins setup |
| 10 minutes | First freestyle job |
| 15 minutes | First Jenkins pipeline |
| 10 minutes | Break and troubleshoot the pipeline |
| 5 minutes | Cleanup and cost verification |

## 2-Hour Extended Session

- add IAM role explanation
- inspect cloud-init logs
- run backup and restore walkthrough
- discuss why not to expose Jenkins publicly

## Pre-Demo Checklist

- AWS CLI authenticated
- Session Manager plugin installed
- region selected
- service quotas checked
- fallback learner IP known if emergency SG rule is needed

## Recovery Plan

If cloud deployment fails:

1. Switch to the local Docker lab.
2. Show the same Jenkins concepts there.
3. Walk through the Terraform code statically.
4. Resume EC2 deployment later as a follow-up exercise.
