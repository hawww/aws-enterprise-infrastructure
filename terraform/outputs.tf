# --- VPC Outputs ---
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_ips
}

# --- EKS Cluster Outputs ---
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_cluster_oidc_issuer_url" {
  description = "OIDC provider URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

# --- RDS Database Outputs ---
output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.rds.db_instance_id
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = module.rds.db_instance_arn
}

# --- Security & Encryption Outputs ---
output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = module.security.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = module.security.kms_key_arn
}

output "central_logs_bucket" {
  description = "S3 bucket for centralized logs"
  value       = module.security.central_logs_bucket_id
}

output "cloudtrail_name" {
  description = "CloudTrail name"
  value       = module.security.cloudtrail_name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}

# --- Monitoring Outputs ---
output "monitoring_sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for EKS"
  value       = module.monitoring.cloudwatch_log_group_name
}

output "prometheus_release" {
  description = "Helm release name for Prometheus"
  value       = module.monitoring.prometheus_release_name
}

# --- Route53 Outputs ---
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.primary.name
}

# --- IAM Role Outputs ---
output "alb_controller_role_arn" {
  description = "ARN of ALB controller IAM role"
  value       = module.iam.alb_controller_role_arn
}

output "ebs_csi_role_arn" {
  description = "ARN of EBS CSI driver IAM role"
  value       = module.iam.ebs_csi_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of Cluster Autoscaler IAM role"
  value       = module.iam.cluster_autoscaler_role_arn
}

# --- Configuration Outputs ---
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "deploy_microservices" {
  description = "Command to deploy microservices"
  value       = "kubectl apply -f k8s-manifests/"
}

output "get_grafana_password" {
  description = "Command to get Grafana admin password"
  value       = "kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode"
}
