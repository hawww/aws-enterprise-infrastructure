# Backup & Disaster Recovery Procedures

## Table of Contents

1. [Overview](#overview)
2. [Backup Strategy](#backup-strategy)
3. [Recovery Procedures](#recovery-procedures)
4. [Testing DR](#testing-dr)
5. [Automation](#automation)

## Overview

### RTO & RPO Targets

| Component | RTO | RPO | Backup Frequency |
|-----------|-----|-----|------------------|
| EKS Cluster | 15 min | 30 min | Continuous (multi-AZ) |
| Microservices | 2 min | 2 min | Deployed automatically |
| RDS Database | 1 min | < 5 min | Continuous (multi-AZ) |
| Terraform State | 5 min | 1 min | Continuous (S3 versioning) |
| EBS Volumes | 30 min | 1 day | Daily snapshots |

## Backup Strategy

### 1. RDS Database Backups

**Automated Backups:**

```bash
# View current backup configuration
aws rds describe-db-instances \
  --db-instance-identifier enterprise-db-prod \
  --query 'DBInstances[0].{
    BackupRetentionPeriod: BackupRetentionPeriod,
    PreferredBackupWindow: PreferredBackupWindow,
    PreferredMaintenanceWindow: PreferredMaintenanceWindow,
    LatestRestorableTime: LatestRestorableTime
  }'

# Output should show:
# - BackupRetentionPeriod: 30 (days)
# - PreferredBackupWindow: 03:00-04:00
# - Multi-AZ: true
# - Cross-region replication: enabled
```

**Backup Verification:**

```bash
# List available backups
aws rds describe-db-snapshots \
  --db-instance-identifier enterprise-db-prod \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table

# Check cross-region replicated backups
aws rds describe-db-snapshots \
  --region us-west-2 \
  --query 'DBSnapshots[?contains(SourceDBInstanceIdentifier, `enterprise`)]' \
  --output table
```

### 2. EBS Snapshots for EKS Nodes

**Manual Snapshot Creation:**

```bash
# Get EKS node volume IDs
VOLUME_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:karpenter.sh/provisioner-name,Values=*" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text)

# Create snapshots
for vol_id in $VOLUME_IDS; do
  aws ec2 create-snapshot \
    --volume-id $vol_id \
    --description "EKS node volume snapshot - $(date +%Y-%m-%d)" \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=eks-backup-'$(date +%Y%m%d)'}]'
done

# List snapshots
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=tag:Name,Values=eks-backup-*" \
  --query 'Snapshots[*].[SnapshotId,StartTime,State,VolumeSize]' \
  --output table
```

**Automated Snapshot Lifecycle:**

```hcl
# Terraform configuration for snapshot scheduling
resource "aws_dlm_lifecycle_policy" "ebs_snapshots" {
  description        = "Daily EBS snapshots for EKS nodes"
  execution_role_arn = aws_iam_role.dlm_role.arn
  state               = "ENABLED"

  policy_details {
    policy_type = "EBS_SNAPSHOT_MANAGEMENT"

    resource_types = ["INSTANCE"]

    target_tags = {
      Backup = "daily"
    }

    schedules {
      name = "daily-snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = 7  # Keep 7 days of snapshots
      }

      tags_to_add = {
        SnapshotType = "automated"
      }
    }
  }
}
```

### 3. Terraform State Backups

**Automated S3 Versioning:**

```bash
# Verify S3 versioning is enabled
aws s3api get-bucket-versioning --bucket enterprise-tfstate-<account>-us-east-1

# Should output:
# "Status": "Enabled"

# List all versions of the state file
aws s3api list-object-versions \
  --bucket enterprise-tfstate-<account>-us-east-1 \
  --prefix enterprise-infra/terraform.tfstate

# Restore previous version if needed
aws s3api get-object \
  --bucket enterprise-tfstate-<account>-us-east-1 \
  --key enterprise-infra/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.backup
```

**Manual State Backup:**

```bash
# Create backup before major changes
terraform state pull > terraform.tfstate.backup

# Store in secure location
cp terraform.tfstate.backup ~/safe/location/terraform.tfstate.backup
chmod 600 ~/safe/location/terraform.tfstate.backup
```

### 4. Kubernetes Persistent Volume Backups

**Backup Pod Volumes:**

```bash
# Install Velero for Kubernetes backup
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
tar -xvf velero-v1.12.0-linux-amd64.tar.gz
cd velero-v1.12.0-linux-amd64

# Install Velero to EKS
./velero install \
  --provider aws \
  --bucket velero-backups \
  --secret-file ./credentials-velero \
  --use-volume-snapshots=true \
  --snapshot-location-config snapshotLocation=us-east-1

# Create backup schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces default,monitoring

# Verify backup
velero backup get
velero backup logs daily-backup-20240101000000
```

### 5. Application Data Backups

**Database Dump (Manual):**

```bash
# Create full database dump
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

pg_dump -h $RDS_ENDPOINT \
  -U dbadmin \
  -d appdb \
  --verbose \
  --format=plain \
  > appdb-backup-$(date +%Y%m%d-%H%M%S).sql

# Compress backup
gzip appdb-backup-*.sql

# Upload to S3 for long-term storage
aws s3 cp appdb-backup-*.sql.gz s3://enterprise-backups/
```

**Continuous Replication (Built-in):**

```bash
# Verify RDS cross-region replication
aws rds describe-db-instances \
  --db-instance-identifier enterprise-db-prod \
  --query 'DBInstances[0].ReadReplicaSourceDBInstanceIdentifier'

# Check replication lag
aws rds describe-db-instances \
  --db-instance-identifier enterprise-db-prod-replica \
  --region us-west-2 \
  --query 'DBInstances[0].ReplicationLag'
```

## Recovery Procedures

### Scenario 1: Single Node Failure

**Symptoms:**
- One EKS node status: NotReady
- Pods on failed node in CrashLoopBackOff

**Recovery Steps:**

```bash
# 1. Check node status
kubectl get nodes
kubectl describe node <failed-node>

# 2. Check pod status on failed node
kubectl get pods --all-namespaces --field-selector spec.nodeName=<failed-node>

# 3. Drain node (evict pods gracefully)
kubectl drain <failed-node> --ignore-daemonsets --delete-emptydir-data

# 4. Delete failed node (will auto-replace due to autoscaling)
kubectl delete node <failed-node>

# 5. Monitor node replacement (takes 2-3 minutes)
kubectl get nodes --watch

# 6. Verify pod rescheduling
kubectl get pods --all-namespaces | grep Running
```

### Scenario 2: Entire EKS Cluster Failure

**Symptoms:**
- Cannot connect to cluster API endpoint
- All nodes down
- No logs from control plane

**Recovery Steps:**

```bash
# 1. Check cluster status
aws eks describe-cluster \
  --name enterprise-eks-prod \
  --query 'cluster.status'

# 2. Check for service interruption
aws eks describe-cluster \
  --name enterprise-eks-prod \
  --query 'cluster.logging.clusterLogging[0].enabled'

# 3. If cluster health issue: Contact AWS Support

# 4. If nodes down but cluster up: Restore from Terraform
terraform apply -auto-approve

# 5. Wait for nodes to fully provision
kubectl get nodes --watch

# 6. Redeploy microservices
kubectl apply -f k8s-manifests/

# 7. Verify application connectivity
kubectl get pods --all-namespaces
kubectl get services
```

### Scenario 3: RDS Database Failure

**Symptoms:**
- Cannot connect to database
- RDS status: "creating-snapshot", "failing-over", or "unavailable"

**Recovery Steps:**

```bash
# 1. Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier enterprise-db-prod \
  --query 'DBInstances[0].{
    DBInstanceStatus: DBInstanceStatus,
    PendingModifiedValues: PendingModifiedValues,
    FailoverStatus: StatusInfos
  }'

# 2. If multi-AZ failover in progress: Wait 1-2 minutes
# AWS handles automatic failover to standby

# 3. If failed: Restore from automated backup
LATEST_BACKUP=$(aws rds describe-db-snapshots \
  --db-instance-identifier enterprise-db-prod \
  --query 'DBSnapshots[0].DBSnapshotIdentifier' \
  --output text)

# Restore to new instance (keep original for data comparison)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier enterprise-db-prod-restored \
  --db-snapshot-identifier $LATEST_BACKUP \
  --multi-az

# 4. Update application connection strings
# Point to new endpoint

# 5. After verification, promote restored instance
# aws rds modify-db-instance --db-instance-identifier enterprise-db-prod-restored \
#   --apply-immediately

# 6. Re-establish replication to standby
aws rds create-db-instance-read-replica \
  --db-instance-identifier enterprise-db-prod-replica \
  --source-db-instance-identifier enterprise-db-prod
```

### Scenario 4: Data Corruption

**Symptoms:**
- Incorrect data in database
- Corrupted records detected
- Need to restore to point-in-time

**Recovery Steps:**

```bash
# 1. Identify point-in-time to restore to
RESTORE_TIME="2024-01-15T10:30:00Z"

# 2. Restore to new instance at specific point in time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier enterprise-db-prod \
  --target-db-instance-identifier enterprise-db-prod-pitr \
  --restore-time $RESTORE_TIME \
  --multi-az

# 3. Wait for restoration to complete (5-10 minutes)
aws rds describe-db-instances \
  --db-instance-identifier enterprise-db-prod-pitr \
  --query 'DBInstances[0].DBInstanceStatus'

# 4. Connect to restored instance and verify data
psql -h enterprise-db-prod-pitr.* -U dbadmin -d appdb
SELECT COUNT(*) FROM important_table;

# 5. Once verified, swap endpoints
# Update application connection strings to point to restored instance

# 6. After application switchover, rename restored instance to primary
aws rds modify-db-instance \
  --db-instance-identifier enterprise-db-prod-pitr \
  --new-db-instance-identifier enterprise-db-prod \
  --apply-immediately
```

### Scenario 5: Complete Region Failure

**Symptoms:**
- AWS region experiencing widespread outage
- Cannot reach any resources in region
- Incident declared by AWS

**Recovery Steps:**

```bash
# 1. Switch DNS to secondary region
# Update Route53 failover record

aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.enterprise.com",
        "Type": "A",
        "SetIdentifier": "primary",
        "Failover": "SECONDARY",
        "HealthCheckId": "<secondary-health-check>",
        "TTL": 60,
        "ResourceRecords": [{
          "Value": "<secondary-alb-ip>"
        }]
      }
    }]
  }'

# 2. Restore RDS read replica in secondary region as primary
aws rds promote-read-replica \
  --db-instance-identifier enterprise-db-replica-us-west-2

# 3. Redeploy EKS cluster in secondary region
cd terraform
terraform workspace new us-west-2
terraform plan -var-file=environments/dr/us-west-2.tfvars
terraform apply

# 4. Deploy microservices to secondary cluster
kubectl apply -f k8s-manifests/

# 5. Run connectivity tests
curl https://app.enterprise.com/users
curl https://app.enterprise.com/orders

# 6. Notify stakeholders of failover
```

## Testing DR

### Monthly DR Drill

```bash
# Schedule: First Saturday of each month, 2-4 AM

# 1. Notify team of upcoming DR test
# 2. Create snapshot of current state for rollback

BACKUP_TAG="dr-test-$(date +%Y%m%d-%Hh)"
terraform state pull > backups/$BACKUP_TAG.tfstate

# 3. Run failover procedure
# 4. Test application functionality for 30 minutes
# 5. Rollback to original state
terraform state push backups/$BACKUP_TAG.tfstate

# 6. Document results and issues
cat > dr-test-results.md << EOF
## DR Test $(date)

### Objectives
- [ ] Confirm RDS backup/recovery works
- [ ] Verify secondary region deployment
- [ ] Test DNS failover

### Results
- RDS recovery time: X minutes
- EKS deployment time: Y minutes
- DNS failover time: Z seconds
- Issues encountered: ...
- Remediation actions: ...

### Recommended improvements
- ...
EOF

# 7. Post-test review with team
```

### Recovery Time Testing

```bash
# Test individual component recovery
# Run weekly to track improvements

# 1. Database recovery test
time aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier enterprise-db-prod \
  --target-db-instance-identifier enterprise-db-test \
  --restore-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --no-copy-tags-to-snapshot

aws rds delete-db-instance \
  --db-instance-identifier enterprise-db-test \
  --skip-final-snapshot

# 2. EKS node recovery test
NODE_TO_TERMINATE=$(kubectl get nodes --no-headers | head -1 | awk '{print $1}')
kubectl drain $NODE_TO_TERMINATE --ignore-daemonsets --delete-emptydir-data
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
  --filters "Name=private-dns-name,Values=$NODE_TO_TERMINATE" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Monitor recovery
kubectl get nodes --watch
# Should see new node join in 3-5 minutes

# 3. Pod recovery test
kubectl delete pod -n monitoring kube-prometheus-stack-prometheus-0
kubectl get pods -n monitoring --watch
# Should see pod restart in < 30 seconds
```

## Automation

### Automated Daily Backup Script

```bash
#!/bin/bash
# backup-daily.sh

set -e

DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/backups/enterprise"
S3_BUCKET="s3://enterprise-backups"

# Create backup directory
mkdir -p $BACKUP_DIR

# 1. Terraform state backup
terraform state pull > $BACKUP_DIR/terraform-$DATE.tfstate
gzip $BACKUP_DIR/terraform-$DATE.tfstate

# 2. Kubernetes manifests backup
kubectl get all -A -o yaml > $BACKUP_DIR/k8s-resources-$DATE.yaml
gzip $BACKUP_DIR/k8s-resources-$DATE.yaml

# 3. PV backups using Velero
velero backup create backup-$DATE

# 4. Upload to S3
aws s3 sync $BACKUP_DIR $S3_BUCKET/

# 5. Cleanup local backups older than 7 days
find $BACKUP_DIR -type f -mtime +7 -delete

# 6. Verify backups
aws s3 ls $S3_BUCKET/ --recursive | tail -10

echo "Backup completed successfully at $(date)"
```

**Install cron job:**

```bash
# Add to crontab
crontab -e

# Add line:
# 0 3 * * * /usr/local/bin/backup-daily.sh >> /var/log/backup-daily.log 2>&1
```

### RDS Backup Monitoring

```bash
#!/bin/bash
# monitor-rds-backups.sh

# Get latest backup time
LATEST_BACKUP=$(aws rds describe-db-snapshots \
  --db-instance-identifier enterprise-db-prod \
  --query 'DBSnapshots[0].SnapshotCreateTime' \
  --output text)

# Check if backup is recent (within 24 hours)
BACKUP_AGE=$(( $(date +%s) - $(date -d "$LATEST_BACKUP" +%s) ))
BACKUP_AGE_HOURS=$(( BACKUP_AGE / 3600 ))

if [ $BACKUP_AGE_HOURS -gt 24 ]; then
  echo "WARNING: RDS backup is older than 24 hours!"
  aws sns publish \
    --topic-arn arn:aws:sns:us-east-1:account:alerts \
    --message "RDS backup stale: Last backup was $BACKUP_AGE_HOURS hours ago"
else
  echo "OK: RDS backup is current ($(date -u -d @$BACKUP_AGE +%Hh%Mm) old)"
fi
```

---

**Backup Frequency Summary:**
- RDS: Continuous (multi-AZ + automated backups + cross-region replication)
- EBS: Daily snapshots (via DLM lifecycle policy)
- Kubernetes: Daily (Velero), on-demand
- Terraform State: Continuous (S3 versioning)
- Application Data: Real-time (RDS replication)

**Last Backup Test**: Document in backups/TEST_LOG.md
**Next Scheduled DR Test**: First Saturday of next month
