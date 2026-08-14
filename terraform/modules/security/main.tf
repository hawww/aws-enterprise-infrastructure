data "aws_caller_identity" "current" {}

# --- KMS Key for Centralized Encryption ---
resource "aws_kms_key" "main" {
  description             = "KMS Key for ${var.project_name} encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = ["kms:GenerateDataKey", "kms:DecryptDataKey"]
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# --- Centralized Encrypted S3 Bucket for Logs ---
resource "aws_s3_bucket" "central_logs" {
  bucket        = "${var.project_name}-central-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.central_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.central_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs_pab" {
  bucket = aws_s3_bucket.central_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.central_logs.id

  rule {
    id     = "archive_old_logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years
    }
  }
}

# S3 bucket policy to allow CloudTrail
resource "aws_s3_bucket_policy" "central_logs" {
  bucket = aws_s3_bucket.central_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.central_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.central_logs.arn}/*"
      }
    ]
  })
}

# --- CloudTrail for Audit Logging ---
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail-${var.environment}"
  s3_bucket_name                = aws_s3_bucket.central_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.main.arn

  depends_on = [aws_s3_bucket_policy.central_logs]
}

# --- GuardDuty for Threat Detection ---
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

# GuardDuty Publishing Destination
resource "aws_guardduty_publishing_destination" "main" {
  detector_id     = aws_guardduty_detector.main.id
  destination_arn = aws_s3_bucket.central_logs.arn
  kms_key_arn     = aws_kms_key.main.arn

  depends_on = [aws_guardduty_detector.main]
}

# --- SecurityHub for Compliance ---
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_organization_admin_account" "main" {
  count            = var.create_securityhub_org_admin ? 1 : 0
  admin_account_id = data.aws_caller_identity.current.account_id
}

# Enable standards
resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "pci_dss" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/pci-dss/v/3.2.1"
}

# --- CloudWatch Log Group for VPC Flow Logs ---
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}"
  retention_in_days = 30

  kms_key_id = aws_kms_key.main.arn

  tags = var.tags
}

# --- IAM Role for VPC Flow Logs ---
resource "aws_iam_role" "vpc_flow_logs" {
  name_prefix = "vpc-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}
