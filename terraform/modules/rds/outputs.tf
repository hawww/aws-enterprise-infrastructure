output "db_instance_endpoint" {
  description = "The connection endpoint of the RDS instance"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = module.rds.db_instance_arn
}

output "db_instance_id" {
  description = "The RDS instance name"
  value       = module.rds.db_instance_id
}

output "db_instance_resource_id" {
  description = "The RDS instance resource ID"
  value       = module.rds.db_instance_resource_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}
