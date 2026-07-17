#!/usr/bin/env bash
set -euo pipefail

INSTANCE_ID="${1:?Usage: verify-instance.sh <instance-id>}"
aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" \
  --query 'Reservations[].Instances[].{State:State.Name,Type:InstanceType,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress}' \
  --output table
