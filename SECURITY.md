# Security Guidelines & Best Practices

## Table of Contents

1. [Overview](#overview)
2. [Pre-Deployment Security](#pre-deployment-security)
3. [Runtime Security](#runtime-security)
4. [Post-Deployment Security](#post-deployment-security)
5. [Incident Response](#incident-response)
6. [Compliance Checklist](#compliance-checklist)

## Overview

This document provides comprehensive security guidance for the enterprise AWS infrastructure deployment. All recommendations align with AWS Well-Architected Framework and industry security standards (CIS, PCI-DSS, SOC 2).

## Pre-Deployment Security

### 1. Credential Management

**DO:**
- Use AWS IAM roles instead of long-lived credentials
- Store Terraform variables in `.tfvars` file (add to .gitignore)
- Use AWS Secrets Manager for sensitive values (RDS passwords, API keys)
- Rotate credentials every 90 days
- Use temporary credentials from AWS STS

**DON'T:**
```bash
# ❌ Bad: Hardcoding credentials in Terraform
variable "db_password" {
  default = "MyPassword123"
}

# ✅ Good: Use AWS Secrets Manager or environment variables
variable "db_password" {
  type        = string
  sensitive   = true
  description = "Get from: aws secretsmanager get-secret-value --secret-id rds-password"
}
```

### 2. Repository Security

**Setup .gitignore:**

```bash
# Create/.gitignore  in repository root
cat > .gitignore << 'EOF'
# Terraform
terraform.tfvars
*.tfstate
*.tfstate.backup
*.tfplan
.terraform/
.terraform.lock.hcl

# Credentials
.env
.env.local
*.key
*.pem
credentials

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
EOF

git add .gitignore
```

**Branch Protection:**

```bash
# In GitHub/GitLab - require:
# - PR review from at least 2 people
# - All CI checks passing
# - Code owners approval for infrastructure changes
# - No direct pushes to main branch
```

### 3. AWS Account Hardening

```bash
# Enable MFA on root account
aws iam enable-mfa-device --user-name root --serial-number arn:aws:iam::ACCOUNT:mfa/root

# Create IAM user for Terraform with minimal permissions
aws iam create-user --user-name terraform-ci

# Create access key (save securely)
aws iam create-access-key --user-name terraform-ci

# Attach policy to Terraform user
aws iam attach-user-policy \
  --user-name terraform-ci \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess  # Or more restrictive

# Enable CloudTrail for root account actions
aws cloudtrail create-trail --name root-account-trail --s3-bucket-name my-cloudtrail-logs
```

### 4. Terraform Backend Security

Before deploying, secure your Terraform state:

```bash
# Enable S3 bucket encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "arn:aws:kms:region:account:key/key-id"
      }
    }]
  }'

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket terraform-state-bucket \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable MFA delete protection
aws s3api put-bucket-versioning \
  --bucket terraform-state-bucket  \
  --versioning-configuration Status=Enabled,MFADelete=Enabled
```

## Runtime Security

### 1. Network Security

**VPC Security Groups - Follow Principle of Least Privilege:**

```bash
# Check current security group rules
aws ec2 describe-security-groups --group-ids sg-12345 --query 'SecurityGroups[0].IpPermissions'

# Don't allow:
# ❌ 0.0.0.0/0 for SSH (port 22)
# ❌ 0.0.0.0/0 for database ports (5432, 3306, 27017)
# ❌ Overly permissive rules (large CIDR blocks)

# Do allow:
# ✅ Specific source security groups
# ✅ Specific IP ranges (corporate VPN, bastion hosts)
# ✅ Restricted port ranges
```

### 2. IAM & RBAC

**Review IAM Roles:**

```bash
# Check what permissions are actually used
aws accessanalyzer validate-policy \
  --policy-document file://iam-policy.json \
  --policy-type IDENTITY_POLICY

# Remove unused permissions regularly
# Use CloudTrail to identify unused permissions

# For Kubernetes RBAC:
kubectl describe rolebinding --all-namespaces | grep -v "^system"
```

**Min-privilege IRSA Example:**

```hcl
# Instead of:
attach_administrator_policy = true

# Use:
inline_policy = {
  read_secrets = {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:region:account:secret:app-*"]
  }
}
```

### 3. Encryption

**Verify Encryption Status:**

```bash
# Check RDS encryption
aws rds describe-db-instances \
  --query 'DBInstances[0].{StorageEncrypted:StorageEncrypted,KmsKeyId:KmsKeyId}'

# Check S3 encryption
aws s3api get-bucket-encryption --bucket my-bucket

# Check EBS encryption (for EKS node volumes)
aws ec2 describe-volumes --query 'Volumes[*].[VolumeId,Encrypted]'

# Check Kubernetes secrets encryption
kubectl get secrets --all-namespaces | head

# Note: Kubernetes secrets are encrypted in etcd if configured
# Verify in EKS cluster settings
aws eks describe-cluster --name my-cluster \
  --query 'cluster.encryption_config'
```

### 4. Audit Logging

**CloudTrail Configuration Review:**

```bash
# Verify multi-region trail
aws cloudtrail describe-trails \
  --query 'trailList[*].[Name,IsMultiRegionTrail,S3BucketName]'

# Check CloudTrail is logging
aws cloudtrail get-trail-status --name my-trail

# Review recent API activity
aws cloudtrail lookup-events \
  --max-results 5 \
  --start-time 2024-01-01T00:00:00Z

# Export logs for analysis
aws s3 sync s3://cloudtrail-bucket/ ./logs/
```

### 5. Secrets Management

**Use AWS Secrets Manager:**

```bash
# Create secret for RDS password
aws secretsmanager create-secret \
  --name prod/rds/password \
  --description "RDS master password" \
  --secret-string "YourSecurePassword123!"

# Reference in Kubernetes pod
kubectl create secret generic db-credentials \
  --from-literal=password=$(aws secretsmanager get-secret-value \
    --secret-id prod/rds/password \
    --query SecretString --output text)

# Note: External Secrets Operator can automate this
```

## Post-Deployment Security

### 1. Security Assessment

**Run AWS Config Rules:**

```bash
# Enable AWS Config
aws configservice put-config-recorder --config-recorder name=default,roleARN=arn:aws:iam::account:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig

# Check for common misconfigurations
aws configservice describe-config-rules \
  --query 'ConfigRules[*].[ConfigRuleName,Source.SourceIdentifier]'
```

**Run WAF on ALB (Optional):**

```bash
# Create WAF WebACL
aws wafv2 create-web-acl \
  --name enterprise-waf \
  --region us-east-1 \
  --scope REGIONAL \
  --default-action Block={} \
  --rules file://waf-rules.json \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=enterprise-waf
```

### 2. Vulnerability Scanning

**Container Image Scanning:**

```bash
# Enable ECR image scanning
aws ecr put-image-scanning-configuration \
  --repository-name my-repo \
  --image-scan-config scanOnPush=true

# Review findings
aws ecr describe-image-scan-findings \
  --repository-name my-repo \
  --image-id imageTag=latest  

# Use tools like:
# - Trivy: Open-source vulnerability scanner
# - Snyk: Developer-first security
# - Aqua Security: Container-native security
```

**Runtime Security Monitoring:**

```bash
# Deploy Falco for runtime security
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace

# Deploy Network Policy Enforcer
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/master/install/kubernetes/quick-install.yaml
```

### 3. Regular Security Tasks

**Weekly:**
- Review CloudTrail logs for suspicious activity
- Check CloudWatch alarms
- Verify all backups successful

**Monthly:**
- Review IAM policies for least privilege
- Check GuardDuty findings
- Review SecurityHub compliance score
- Audit VPC security groups

**Quarterly:**
- Penetration testing
- Security audit of deployed applications
- Review and update security documentation

### 4. Monitoring & Detection

**Setup GuardDuty Findings Analysis:**

```bash
# List recent GuardDuty findings
aws guardduty list-findings \
  --detector-id <detector-id> \
  --finding-criteria '{"Criterion":{"updatedAt":{"Gte":1234567890}}}'

# Get finding details
aws guardduty get-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id>

# Setup CloudWatch Events rule to notify on GuardDuty findings
aws events put-rule \
  --name guardduty-findings \
  --event-pattern '{
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"]
  }'
```

**Setup SecurityHub Dashboard:**

```bash
# Enable security standards
aws securityhub batch-enable-standards \
  --standards-subscription-requests '[
    {
      "StandardsArn": "arn:aws:securityhub:region:account:standards/aws-foundational-security-best-practices/v/1.0.0"
    },
    {
      "StandardsArn": "arn:aws:securityhub:region:account:standards/pci-dss/v/3.2.1"
    }
  ]'

# Get compliance status
aws securityhub get-compliance-summary
```

## Incident Response

### 1. Suspected Credentials Compromise

```bash
# IMMEDIATE: Disable IAM user access key
aws iam update-access-key \
  --access-key-id <key-id> \
  --user-name <user> \
  --status Inactive

# Create new access key
aws iam create-access-key --user-name <user>

# Check CloudTrail for suspicious activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<key-id>

# Review all changes made by this key
# Revert any unauthorized changes
# Delete old access key
aws iam delete-access-key --access-key-id <key-id> --user-name <user>
```

### 2. Suspected Data Breach

```bash
# IMMEDIATE: Check recent S3 access logs
aws s3api get-object-acl --bucket my-bucket --key my-file | grep -i "permission"

# Check VPC Flow Logs for unusual traffic
aws ec2 describe-flow-logs --filter Name=resource-id,Values=<resource-id>

# Verify database audit logs (if enabled)
aws rds describe-db-log-files --db-instance-identifier <instance>

# Enable access logging if not already
aws rds modify-db-instance \
  --db-instance-identifier <instance> \
  --enable-cloudwatch-logs-exports postgresql

# Review RDS performance insights
# Look for unusual queries from unauthorized users
```

### 3. Suspected DDoS Attack

```bash
# Check CloudWatch metrics for ALB
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=<alb-name> \
  --statistics Sum \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z \
  --period 60

# Enable AWS Shield Standard (included free)
# Consider AWS Shield Advanced ($3,000/month)

# Enable WAF rules for DDoS protection
aws wafv2 create-web-acl \
  --name ddos-protection \
  --scope REGIONAL \
  --default-action Block={}
```

## Compliance Checklist

### CIS AWS Foundations Benchmark

- [ ] Root account MFA enabled
- [ ] Cloudtrail enabled for all regions
- [ ] CloudTrail logs encrypted with KMS
- [ ] CloudTrail log file validation enabled
- [ ] CloudWatch Logs for CloudTrail enabled
- [ ] AWS Config enabled
- [ ] GuardDuty enabled
- [ ] VPC Flow Logs enabled
- [ ] S3 bucket encryption enabled
- [ ] S3 bucket default encryption enabled
- [ ] S3 bucket public access blocked
- [ ] IAM password policy enforced
- [ ] IAM MFA for all users enabled
- [ ] Unused credentials removed
- [ ] Unused security groups removed
- [ ] Unused network ACLs removed
- [ ] Database encryption enabled
- [ ] S3 object versioning enabled

### PCI-DSS v3.2.1

- [ ] Firewall configuration in place (Security Groups)
- [ ] Default passwords changed (RDS, Grafana)
- [ ] Encryption in transit enabled (TLS)
- [ ] Encryption at rest enabled (KMS)
- [ ] Access control configured (IAM, RBAC)
- [ ] Logging and monitoring enabled (CloudTrail, GuardDuty)
- [ ] Security policy documented
- [ ] Regular assessments scheduled

### HIPAA Compliance (if applicable)

- [ ] Encryption at rest with customer-managed keys (KMS)
- [ ] Encryption in transit (TLS 1.2+)
- [ ] Access logging enabled (CloudTrail)
- [ ] Audit controls implemented (GuardDuty, SecurityHub)
- [ ] Business Associate Agreement (BAA) signed with AWS
- [ ] Data breach notification procedures documented

## Security Tools & Resources

### AWS Tools
- **AWS SecurityHub**: Centralized security findings
- **AWS Config**: Configuration compliance
- **AWS Inspector**: Vulnerability assessments (EC2 agents)
- **Amazon GuardDuty**: Threat detection
- **AWS CloudTrail**: Audit logging
- **AWS WAF**: Web application firewall
- **AWS Shield**: DDoS protection

### Third-Party Tools
- **Trivy**: Vulnerability scanner (containers)
- **Falco**: Runtime security monitoring
- **OPA/Gatekeeper**: Policy-as-code for Kubernetes
- **Vault**: Secrets management
- **Dome9**: Cloud compliance monitoring

### Documentation
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services/)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)

---

**Remember**: Security is a continuous process, not a one-time task. Regular reviews, updates, and monitoring are essential for maintaining a secure infrastructure.

**Last Updated**: 2024
