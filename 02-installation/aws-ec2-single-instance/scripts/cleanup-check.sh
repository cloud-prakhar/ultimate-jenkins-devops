#!/usr/bin/env bash
set -euo pipefail

echo "Review these before finishing:"
echo "- EC2 instance deleted or intentionally retained"
echo "- EBS volumes deleted if no longer needed"
echo "- Security group rules tightened or removed"
echo "- Session Manager tunnels closed"
