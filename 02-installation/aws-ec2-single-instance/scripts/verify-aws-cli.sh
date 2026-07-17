#!/usr/bin/env bash
set -euo pipefail

aws --version
session-manager-plugin --version
aws sts get-caller-identity
