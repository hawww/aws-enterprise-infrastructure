output "alb_controller_role_arn" {
  description = "ARN of the ALB controller IAM role"
  value       = module.alb_irsa.iam_role_arn
}

output "ebs_csi_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = module.ebs_csi_irsa.iam_role_arn
}

output "monitoring_role_arn" {
  description = "ARN of the monitoring IAM role"
  value       = module.monitoring_irsa.iam_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "external_dns_irsa_role_arn" {
  value = module.external_dns_irsa.iam_role_arn
}