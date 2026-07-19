# 03 - Terraform Deployment

## Goal

Provision the lab repeatably using Terraform without over-engineering the module.

## Commands

```bash
cd terraform
terraform init
cp terraform.tfvars.example terraform.tfvars
terraform fmt
terraform validate
terraform plan
terraform apply
```

## What Terraform Creates

- optional VPC and public subnet
- security group
- IAM role and instance profile
- Ubuntu 24.04 EC2 instance
- EBS-backed root volume sized for Jenkins

## Validation

```bash
terraform output instance_id
terraform output ssm_port_forward_command
```

## What Happens on the Instance

`terraform apply` returns as soon as EC2 reports the instance as running —
**Jenkins is not ready yet at that moment.** The `user-data.sh` bootstrap is
still installing Java and Jenkins in the background, which takes another
3-6 minutes.

Note that `user_data_replace_on_change = true` is set on the instance: editing
`user-data.sh` and re-applying **replaces the instance** so the new script
actually runs. Without it, Terraform would record the change and leave the
running server untouched.

## Next Steps

Do not open the browser yet. Go to
[04-installing-jenkins.md](./04-installing-jenkins.md) and follow it from
Step 1 — it covers connecting over SSM, confirming the bootstrap succeeded,
diagnosing it when `systemctl status jenkins` reports
`Unit jenkins.service could not be found`, opening the port-forward tunnel,
and unlocking the setup wizard.

## Cleanup

```bash
terraform destroy
```
