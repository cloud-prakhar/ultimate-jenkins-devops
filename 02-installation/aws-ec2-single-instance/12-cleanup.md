# 12 - Cleanup

## Manual Cleanup

- stop Jenkins if you want a clean shutdown
- delete the EC2 instance
- delete attached EBS volumes if they were not set to delete on termination
- delete the security group and IAM role if they were created only for the lab

## Terraform Cleanup

```bash
terraform -chdir=terraform destroy
```

## Cost Check

Before you finish, verify:

- no EC2 instance remains
- no unattached EBS volume remains
- no Elastic IP remains if you created one
