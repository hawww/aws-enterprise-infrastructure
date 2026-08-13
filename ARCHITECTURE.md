# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│           AWS Account (us-east-1)                   │
├─────────────────────────────────────────────────────┤
│                                                     │
│              ┌─────────────────────┐               │
│              │  Application Layer  │               │
│              │ ┌─────────────────┐ │               │
│              │ │  User Service   │ │               │
│              │ │  Order Service  │ │               │
│              │ └─────────────────┘ │               │
│              │  (EKS Pods)         │               │
│              └──────────┬──────────┘               │
│                         │                         │
│              ┌──────────▼──────────┐              │
│              │   ALB Ingress       │              │
│              │  (AWS LB Controller)│              │
│              └──────────┬──────────┘              │
│                         │                         │
│  ┌──────────────────────┼──────────────────────┐  │
│  │     VPC: 10.0.0.0/16 │                     │  │
│  │                      │                     │  │
│  │  ┌──────────────────┴──────────────────┐  │  │
│  │  │   Public Subnets (AZ-1, AZ-2)       │  │  │
│  │  │   ┌─────────────────────────────┐   │  │  │
│  │  │   │ NAT Gateway 1 (us-east-1a) │   │  │  │
│  │  │   └─────────────────────────────┘   │  │  │
│  │  │   ┌─────────────────────────────┐   │  │  │
│  │  │   │ NAT Gateway 2 (us-east-1b) │   │  │  │
│  │  │   └─────────────────────────────┘   │  │  │
│  │  └──────────────────────────────────┘  │  │  │
│  │                                         │  │  │
│  │  ┌──────────────────────────────────┐  │  │  │
│  │  │   Private Subnets (AZ-1, AZ-2)   │  │  │  │
│  │  │                                  │  │  │  │
│  │  │   AZ-1 (us-east-1a):             │  │  │  │
│  │  │   ┌────────────────────────────┐ │  │  │  │
│  │  │   │ EKS Nodes  (t3.medium)    │ │  │  │  │
│  │  │   │ - CPU: 2 cores            │ │  │  │  │
│  │  │   │ - Memory: 4 GB            │ │  │  │  │
│  │  │   │ - Storage: 100 GB (gp3)   │ │  │  │  │
│  │  │   └────────────────────────────┘ │  │  │  │
│  │  │                                  │  │  │  │
│  │  │   AZ-2 (us-east-1b):             │  │  │  │
│  │  │   ┌────────────────────────────┐ │  │  │  │
│  │  │   │ EKS Nodes  (t3.medium)    │ │  │  │  │
│  │  │   └────────────────────────────┘ │  │  │  │
│  │  │                                  │  │  │  │
│  │  │   ┌────────────────────────────┐ │  │  │  │
│  │  │   │ RDS Primary (Multi-AZ)    │ │  │  │  │
│  │  │   │ PostgreSQL 15             │ │  │  │  │
│  │  │   │ db.t3.micro               │ │  │  │  │
│  │  │   └────────────────────────────┘ │  │  │  │
│  │  └──────────────────────────────────┘  │  │  │
│  │                                         │  │  │
│  │  ┌──────────────────────────────────┐  │  │  │
│  │  │ Database Subnets (for RDS)       │  │  │  │
│  │  │ (Spanning AZ-1 and AZ-2)         │  │  │  │
│  │  └──────────────────────────────────┘  │  │  │
│  └─────────────────────────────────────────┘  │  │
│                                               │  │
│  ┌───────────────────────────────────────┐    │  │
│  │    Security & Monitoring              │    │  │
│  │  • CloudTrail (Audit logs)           │    │  │
│  │  • GuardDuty (Threat detection)      │    │  │
│  │  • SecurityHub (Compliance)          │    │  │
│  │  • KMS (Encryption keys)             │    │  │
│  │  • CloudWatch (Centralized logs)     │    │  │
│  │  • Prometheus & Grafana (Metrics)    │    │  │
│  │  • SNS Topics (Alerting)             │    │  │
│  │  • S3 (Central log storage)          │    │  │
│  └───────────────────────────────────────┘    │  │
│                                               │  │
└───────────────────────────────────────────────┘  │
```

## Component Details

### 1. Virtual Private Cloud (VPC)

**Network Design:**
- VPC CIDR: 10.0.0.0/16
- Public Subnets: 10.0.101.0/24 (AZ-1), 10.0.102.0/24 (AZ-2)
- Private Subnets: 10.0.1.0/24 (AZ-1), 10.0.2.0/24 (AZ-2)
- Database Subnets: Managed by VPC module

**Features:**
- 2 NAT Gateways (High Availability) - one per AZ
- Internet Gateway for ingress traffic
- VPC Flow Logs for network monitoring
- Security groups with least privilege rules

### 2. Amazon EKS Cluster

**Cluster Configuration:**
- Kubernetes Version: 1.28
- Control Plane: Managed by AWS
- Node Groups: One managed node group with:
  - Instance Type: t3.medium (2 vCPU, 4GB RAM)
  - Min Size: 2 nodes
  - Max Size: 4 nodes
  - Desired Size: 2 nodes
  - Capacity Type: On-Demand

**Add-ons:**
- aws-ebs-csi-driver: For persistent volumes
- coredns: DNS service for pods
- kube-proxy: Network proxy for Kubernetes
- vpc-cni: AWS VPC CNI for pod networking

**Controllers Installed:**
- AWS Load Balancer Controller: ALB/NLB provisioning
- Cluster Autoscaler: Auto-scale node groups
- CoreDNS: DNS for service discovery

### 3. Microservices

**User Service:**
- Image: nginx:alpine (sample)
- Replicas: 2 (min) to 10 (max) via HPA
- CPU: 100m (request), 250m (limit)
- Memory: 128Mi (request), 256Mi (limit)
- Health Check: Readiness & Liveness probes (auto-configured)
- Pod Disruption Budget: Minimum 1 available pod

**Order Service:**
- Image: nginx:alpine (sample)
- Replicas: 2 (min) to 10 (max) via HPA
- CPU: 100m (request), 250m (limit)
- Memory: 128Mi (request), 256Mi (limit)
- Pod Disruption Budget: Minimum 1 available pod

**Ingress:**
- Type: ALB (AWS Load Balancer Controller)
- Routing: Path-based (/users → user-service, /orders → order-service)
- Health Checks: Every 15 seconds, 2 healthy threshold
- Attributes: Keep-alive enabled for connection reuse

### 4. RDS PostgreSQL Database

**Configuration:**
- Engine: PostgreSQL 15.4
- Instance Class: db.t3.micro (1 vCPU, 1GB RAM)
- Allocated Storage: 20 GB
- Max Allocated Storage: 100 GB (auto-scaling)
- Multi-AZ: Enabled (standby in different AZ)
- Database: appdb
- Master Username: dbadmin

**Features:**
- Automated Backups: 30-day retention
- Backup Window: 03:00-04:00 UTC
- Maintenance Window: Monday 04:00-05:00 UTC
- Encryption: KMS at rest
- Enhanced Monitoring: Every 60 seconds
- Performance Insights: 7-day retention
- Cross-Region Replication: To us-west-2 (DR)

**Security:**
- Private subnet placement (no public access)
- Security group limited to EKS nodes only
- Deletion protection enabled
- Multi-AZ for automatic failover

### 5. Security & Compliance

**Encryption:**
- KMS Master Key: Rotated annually
- Data at Rest: All S3, RDS, EBS encrypted with KMS
- Data in Transit: TLS/HTTPS everywhere
- Secrets: Stored in AWS Secrets Manager (optional)

**Audit & Compliance:**
- CloudTrail: Multi-region trail capturing all API calls
- CloudTrail Logs: Stored in encrypted S3 bucket with versioning
- CloudTrail Retention: Indefinite with Glacier archival after 90 days
- GuardDuty: Threat detection enabled
- SecurityHub: CIS Foundations, PCI DSS standards enabled

**Access Control:**
- VPC Security Groups: Whitelist-based rules
- Network Policies: Pod-to-pod communication restricted
- IAM Policies: Least privilege (IRSA for service accounts)
- VPC Endpoints: For private AWS API access (optional)

### 6. Monitoring & Observability

**CloudWatch:**
- Log Groups: EKS control plane, application logs
- Log Retention: 30 days
- Metrics: CPU, Memory, Network, Disk I/O
- Alarms: High CPU (>80%), High Memory (>80%)
- Dashboard: Custom dashboard for key metrics

**Prometheus & Grafana:**
- Prometheus: Collects metrics every 30 seconds
- Retention: 30 days
- Grafana: Visualization and dashboards
- Storage: EBS volume (gp3) with 10GB allocation
- Admin Password: Set during deployment

**Alerting:**
- SNS Topic: For critical alerts
- Channels: Email (optional), custom integrations
- Conditions: High resource utilization, pod failures

### 7. Disaster Recovery

**Strategy:**
- **RTO**: < 15 minutes
- **RPO**: < 5 minutes

**Components:**
- Multi-AZ EKS: Nodes spread across 2 AZs
- Multi-AZ RDS: Primary + Standby (automatic failover)
- EBS Snapshots: Automated daily snapshots
- Terraform State: S3 backend with versioning
- Regional Failover: Route53 health checks + manual failover

**Backup Profile:**
- EKS: Node state in EBS snapshots
- RDS: Automated backups, cross-region replication
- Application Data: Kubernetes PVs backed by EBS
- Terraform State: Versioned S3 bucket

## Data Flow

### Request Flow (Ingress)
```
Internet
   ↓
ALB (Security Group allows ports 80/443)
   ↓
Kubernetes Ingress (Annotation: ingress.kubernetes.io/ingress.class: alb)
   ↓
Service (user-service or order-service)
   ↓
Pods (Running in private subnets)
   ↓
RDS Database (PostgreSQL)
```

### Response Flow
```
RDS → Pods → Service → ALB → Internet
```

### Networking Path
```
Pod (10.0.1.x) → NAT Gateway → Internet
Internet → NAT Gateway / IGW → EKS Node → Pod
```

## Scalability

### Auto-Scaling

**Horizontal Pod Autoscaling (HPA):**
- Metrics: CPU (70% target), Memory (80% target)
- Min Replicas: 2
- Max Replicas: 10
- Scale-up: Immediate (0 seconds stabilization)
- Scale-down: 300 seconds stabilization

**Cluster Autoscaling:**
- Min Nodes: 2
- Max Nodes: 4
- Auto-add nodes when pods can't be scheduled
- Auto-remove nodes when underutilized

**RDS Auto-Scaling:**
- Allocated Storage: 20 GB → 100 GB
- Automatically scales when reaching 90% threshold

## High Availability

**EKS Cluster:**
- Multi-AZ deployment
- Service replicas across nodes
- Pod disruption budgets
- Health checks & automatic restart

**RDS Database:**
- Multi-AZ with synchronous replication
- Automatic failover  (1-2 minutes)
- Read replicas in same region

**Networking:**
- Dual NAT Gateways (one per AZ)
- Load balancing across multiple pods
- Health checks at ALB level

## Security Layers

```
Layer 1: Edge Security
├── AWS WAF (Optional on ALB)
├── Security groups (allow ports 80/443)
└── DDoS protection (AWS Shield Standard/Advanced)

Layer 2: Network Security
├── VPC isolation
├── Private subnets for compute
├── Network policies (Kubernetes)
└── NACLs (Network ACLs)

Layer 3: Application Security
├── Pod security standards
├── Service account RBAC
├── Secrets encryption (KMS)
└── Resource quotas & limits

Layer 4: Data Security
├── Encryption at rest (KMS)
├── Encryption in transit (TLS)
├── Database encryption
└── S3 secure configuration

Layer 5: Monitoring & Detection
├── CloudTrail (audit)
├── GuardDuty (threats)
├── SecurityHub (compliance)
├── CloudWatch (metrics)
└── VPC Flow Logs (network)
```

## Compliance Mapping

| Requirement | Implementation |
|-------------|-----------------|
| Audit Logging | CloudTrail + S3 |
| Encryption at Rest | KMS for all services |
| Encryption in Transit | TLS/HTTPS enforced |
| Access Control | IAM + IRSA + Security Groups |
| Network Isolation | VPC + Private Subnets |
| Monitoring | CloudWatch + Prometheus|
| Incident Response | GuardDuty + SecurityHub |
| Backup & Recovery | RDS + EBS + Terraform State |

---

This architecture provides enterprise-grade reliability, security, and scalability for production workloads.
