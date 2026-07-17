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

## Cleanup

```bash
terraform destroy
```
