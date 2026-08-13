# Pre-Deployment Checklist

## AWS Account Setup

- [ ] AWS account created and active
- [ ] Billing information configured
- [ ] AWS Organizations set up (if using multiple accounts)
- [ ] Cost allocation tags defined

## IAM & Credentials

- [ ] Root account MFA enabled (physical key or authenticator app)
- [ ] Terraform IAM user created with appropriate permissions
- [ ] AWS Access Key ID and Secret Key generated (saved securely)
- [ ] AWS CLI configured: `aws configure`
- [ ] Credentials verified: `aws sts get-caller-identity`
- [ ] 2FA enabled for all human users (if using AWS console)

## Local Environment

- [ ] Terraform >= 1.5.0 installed: `terraform -version`
- [ ] AWS CLI v2 installed: `aws --version`
- [ ] kubectl installed: `kubectl version --client`
- [ ] helm installed: `helm version`
- [ ] Git installed (for version control)
- [ ] Text editor/IDE configured (VS Code recommended)

## Repository Setup

- [ ] Repository cloned or downloaded
- [ ] Directory structure verified:
  ```bash
  ls -la terraform/
  # Should show: modules/, k8s-manifests/, main.tf, variables.tf, etc.
  ```
- [ ] .gitignore configured to exclude sensitive files
- [ ] Git initialized: `git init`
- [ ] Git remote added (if using version control)

## AWS Service Quotas

- [ ] VPC count quota check:
  ```bash
  aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-7BED4A37 \
    --query 'Quota.Value'
  ```
  (Need: 1 VPC, Default: 5)

- [ ] Network Interface quota check:
  ```bash
  aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-6E80429E \
    --query 'Quota.Value'
  ```
  (Need: ~20 ENIs, Default: 130)

- [ ] Elastic IP quota check:
  ```bash
  aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-1C2C1265 \
    --query 'Quota.Value'
  ```
  (Need: 2 NAT IPs, Default: 5)

- [ ] If any quotas too low, request increase in AWS console

## Configuration Files

- [ ] terraform/terraform.tfvars file exists
- [ ] `db_password` set to secure value (not default)
- [ ] `grafana_admin_password` changed from default
- [ ] `aws_region` set correctly (us-east-1 or preferred region)
- [ ] `project_name` updated if needed
- [ ] `alert_email` configured (optional but recommended)
- [ ] All sensitive values removed from version control
- [ ] `terraform.tfvars` added to `.gitignore`

## Remote Backend (S3 + DynamoDB)

**If using remote backend (recommended for production):**

- [ ] S3 bucket created:
  ```bash
  aws s3api create-bucket --bucket enterprise-tfstate-<ACCOUNT>-<REGION>
  ```
- [ ] S3 bucket versioning enabled:
  ```bash
  aws s3api put-bucket-versioning \
    --bucket enterprise-tfstate-<ACCOUNT>-<REGION> \
    --versioning-configuration Status=Enabled
  ```
- [ ] S3 bucket encryption enabled (AES256 or KMS)
- [ ] S3 bucket public access blocked
- [ ] DynamoDB table created:
  ```bash
  aws dynamodb create-table --table-name enterprise-tflock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
  ```
- [ ] backend.tf uncommented and bucket/table names updated
- [ ] `terraform init` run to migrate state to S3

**Or for local state:**
- [ ] Local backup directory created: `mkdir -p ~/backups/terraform`
- [ ] State backup procedure documented
- [ ] Terraform state pull command tested: `terraform state pull`

## Terraform Initialization

- [ ] Working directory is `terraform/`
- [ ] Run: `terraform init`
  - [ ] Providers downloaded successfully
  - [ ] Modules downloaded successfully
  - [ ] Backend initialized (S3 or local)
- [ ] Run: `terraform validate`
  - [ ] No syntax errors reported
- [ ] Run: `terraform fmt -recursive`
  - [ ] Code formatting consistent

## Pre-Deployment Validation

- [ ] All module files present:
  - [ ] modules/vpc/main.tf, variables.tf, outputs.tf
  - [ ] modules/eks/main.tf, variables.tf, outputs.tf
  - [ ] modules/iam/main.tf, variables.tf, outputs.tf
  - [ ] modules/security/main.tf, variables.tf, outputs.tf
  - [ ] modules/rds/main.tf, variables.tf, outputs.tf
  - [ ] modules/monitoring/main.tf, variables.tf, outputs.tf

- [ ] Kubernetes manifests present:
  - [ ] k8s-manifests/microservice-user.yaml
  - [ ] k8s-manifests/microservice-order.yaml
  - [ ] k8s-manifests/ingress.yaml

- [ ] Documentation files present:
  - [ ] README.md
  - [ ] ARCHITECTURE.md
  - [ ] DEPLOYMENT_GUIDE.md
  - [ ] SECURITY.md
  - [ ] BACKUP_RESTORE.md
  - [ ] QUICK_REFERENCE.md

- [ ] Run final plan:
  ```bash
  terraform plan -out=tfplan
  ```
  - [ ] Plan completes without errors
  - [ ] Review resource count (should be ~156 resources)
  - [ ] No unexpected deletions
  - [ ] All variables resolved correctly

## Security Pre-Checks

- [ ] AWS CloudTrail enabled on account
- [ ] GuardDuty enabled (if required for your org)
- [ ] VPC Flow Logs will be enabled by Terraform
- [ ] S3 bucket encryption configured in plan
- [ ] KMS key policy reviewed
- [ ] RDS multi-AZ enabled (verified in plan)
- [ ] No passwords hardcoded in Terraform files
- [ ] `.gitignore` includes `*.tfvars`

## Team Communication

- [ ] Deployment time window scheduled
  - [ ] Off-peak suggested (2-4 hours)
  - [ ] Avoid critical business hours
  - [ ] Team notified of expected 30-45 minute deployment

- [ ] Rollback plan communicated
- [ ] Escalation contacts identified
- [ ] Stakeholders informed of start time

## Network & Connectivity

- [ ] Network connectivity verified:
  ```bash
  aws ec2 describe-regions
  ```
- [ ] No corporate proxy blocking AWS API calls (if applicable)
- [ ] VPN connected if required
- [ ] SSH key pair generated for EC2 access (if needed)
  ```bash
  aws ec2 create-key-pair --key-name enterprise-keypair \
    --query 'KeyMaterial' > enterprise-keypair.pem
  chmod 600 enterprise-keypair.pem
  ```

## Post-Deployment Preparation

- [ ] kubectl installed and PATH configured
- [ ] helm installed and PATH configured
- [ ] Kubectl bash completion installed (optional):
  ```bash
  kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl
  ```
- [ ] Kubeconfig backup location prepared:
  ```bash
  mkdir -p ~/.kube/backups
  ```

## Rollback Plan

- [ ] Terraform state backup created:
  ```bash
  terraform state pull > backup-predeployment.tfstate
  chmod 600 backup-predeployment.tfstate
  ```
- [ ] Backup stored in secure location
- [ ] Destroy command tested (not executed):
  ```bash
  terraform plan -destroy
  ```
- [ ] Team understands rollback procedure
- [ ] Estimated rollback time: 15-20 minutes

## Final Checklist

- [ ] All above items completed
- [ ] Team is ready for deployment
- [ ] Deployment window confirmed
- [ ] Monitoring tools ready (CloudWatch, logs, terminal windows)
- [ ] Documentation printed or readily available
- [ ] Communication channels open (Slack, Teams,  phone)

---

## Approved By

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Infrastructure Lead | | | |
| Security Lead | | | |
| Project Manager | | | |

---

## Deployment Start

**Deployment Date**: ___________

**Expected Duration**: 30-45 minutes

**Environment**: ___________

**Deployed By**: ___________

**Start Time**: ___________

**Completion Time**: ___________

**Status**: 
- [ ] Success
- [ ] Partial Success (please detail below)
- [ ] Failed (see rollback section)

---

## Notes & Issues

```
(Use this section to document any issues encountered during deployment)


```

---

**Post-Deployment**: Verify checklist in DEPLOYMENT_GUIDE.md section "Verification"

**Documentation**: Refer to QUICK_REFERENCE.md for common commands
