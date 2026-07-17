variable "aws_region" {
  description = "AWS region for the Jenkins lab."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Jenkins host."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB."
  type        = number
  default     = 50
  validation {
    condition     = var.root_volume_size >= 30
    error_message = "Use at least 30 GiB for a Jenkins lab."
  }
}

variable "create_vpc" {
  description = "Whether to create a minimal VPC and subnet for the lab."
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "Existing VPC ID to use when create_vpc is false."
  type        = string
  default     = null
}

variable "existing_subnet_id" {
  description = "Existing subnet ID to use when create_vpc is false."
  type        = string
  default     = null
}

variable "allowed_cidr_for_jenkins" {
  description = "Optional less-secure fallback CIDR allowed to reach port 8080."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
  default     = "jenkins-lab"
}
