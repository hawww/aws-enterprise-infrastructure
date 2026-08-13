output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the EKS CloudWatch log group"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "prometheus_release_name" {
  description = "Helm release name for Prometheus"
  value       = helm_release.kube_prometheus_stack.name
}
