output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = aws_kms_key.main.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  value       = aws_kms_key.main.arn
}

output "central_logs_bucket_id" {
  description = "ID of the centralized logs S3 bucket"
  value       = aws_s3_bucket.central_logs.id
}

output "central_logs_bucket_arn" {
  description = "ARN of the centralized logs S3 bucket"
  value       = aws_s3_bucket.central_logs.arn
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = aws_cloudtrail.main.name
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "vpc_flow_logs_group_name" {
  description = "Name of the CloudWatch log group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}
