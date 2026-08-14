variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_instance_types" {
  description = "Instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for cluster encryption"
  type        = string
}

#variable "ebs_csi_role_arn" {
#  description = "ARN of EBS CSI driver IAM role"
#  type        = string
#}

#variable "alb_controller_role_arn" {
#  description = "ARN of ALB controller IAM role"
#  type        = string
#}

#variable "cluster_autoscaler_role_arn" {
#  description = "ARN of Cluster Autoscaler IAM role"
#  type        = string
#}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}
