variable "cluster_name" {}
variable "ebs_csi_role_arn" {}
variable "alb_controller_role_arn" {}
variable "cluster_autoscaler_role_arn" {}

variable "aws_region" {
  type = string
}