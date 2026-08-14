# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "rds-"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    description     = "Allow PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = var.tags
}

# RDS Module
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.4.0"

  identifier = "${var.project_name}-db-${var.environment}"

  # Engine Configuration
  engine                = "postgres"
  engine_version        = var.db_engine_version
  family                = var.db_family
  major_engine_version  = var.db_major_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # Multi-AZ Configuration
  multi_az               = true
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Encryption and Security
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Backup Configuration
  backup_retention_period          = var.backup_retention_days
  backup_window                    = "03:00-04:00"
  maintenance_window               = "mon:04:00-mon:05:00"
  skip_final_snapshot              = false
  final_snapshot_identifier_prefix = "${var.project_name}-db-${var.environment}-final-"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = var.kms_key_arn

  # CloudWatch Logs
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Monitoring
  #enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # DeletionProtection
  deletion_protection = true

  tags = merge(
    var.tags,
    {
      "Backup" = "daily"
    }
  )
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# DB Parameter Group with recommended settings
resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.project_name}-"
  family      = var.db_family

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  tags = var.tags
}

# Automated backup snapshot copy to another region for DR
resource "aws_db_instance_automated_backups_replication" "main" {
  provider = aws.dr
  source_db_instance_arn = module.rds.db_instance_arn

  kms_key_id = var.kms_key_arn
}

# EventSubscription for RDS Events
resource "aws_db_event_subscription" "main" {
  name_prefix = "${var.project_name}-"

  sns_topic = var.sns_topic_arn

  source_type      = "db-instance"
  event_categories = ["availability", "backup", "failure", "recovery"]

  tags = var.tags
}