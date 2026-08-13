# Quick Reference Guide

## Table of Contents
- [Terraform Commands](#terraform-commands)
- [Kubernetes Commands](#kubernetes-commands)
- [AWS CLI Commands](#aws-cli-commands)
- [Troubleshooting](#troubleshooting)

## Terraform Commands

### Initialization & Validation
```bash
# Initialize Terraform (download providers and modules)
terraform init

# Validate configuration syntax
terraform validate

# Format code to standard
terraform fmt -recursive

# Check for security issues
terraform plan -json | tfsec --json
```

### Planning & Deployment
```bash
# See what will be created/modified
terraform plan -out=tfplan

# Deploy infrastructure
terraform apply tfplan

# Destroy infrastructure (with confirmation)
terraform destroy

# Destroy without confirmation (careful!)
terraform destroy -auto-approve
```

### State Management
```bash
# View current state
terraform show

# Pull state from backend
terraform state pull > backup.tfstate

# Push state to backend
terraform state push backup.tfstate

# List resources in state
terraform state list

# Show specific resource
terraform state show 'module.eks.module.eks.aws_eks_cluster.this'

# Remove resource from state (careful!)
terraform state rm 'aws_instance.example'
```

### Outputs & Information
```bash
# Show all outputs
terraform output

# Get specific output value
terraform output eks_cluster_name
terraform output rds_endpoint

# Get output in JSON
terraform output -json

# Get raw output value
terraform output -raw eks_cluster_endpoint
```

### Workspace Management
```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new dev

# Switch workspace
terraform workspace select dev

# Delete workspace
terraform workspace delete dev
```

---

## Kubernetes Commands

### Cluster Information
```bash
# Get cluster info
kubectl cluster-info

# Get nodes status
kubectl get nodes
kubectl get nodes -o wide

# Get node details
kubectl describe node <node-name>

# Get cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Deployments & Pods
```bash
# Get deployments
kubectl get deployments
kubectl get deployments -n monitoring

# Describe deployment
kubectl describe deployment user-service

# Get pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods --all-namespaces

# Get pod details
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> -f  # Follow logs
kubectl logs <pod-name> -c <container>  # Specific container

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash
```

### Services & Ingress
```bash
# Get services
kubectl get services
kubectl get services --all-namespaces

# Get ingress
kubectl get ingress
kubectl describe ingress app-ingress

# Get ALB details
kubectl describe ingress app-ingress | grep "LoadBalancer Ingress"
```

### Horizontal Pod Autoscaler (HPA)
```bash
# Get HPA status
kubectl get hpa
kubectl get hpa user-service-hpa

# Describe HPA
kubectl describe hpa user-service-hpa

# Watch HPA scaling
kubectl get hpa --watch

# Edit HPA
kubectl edit hpa user-service-hpa
```

### Pod Disruption Budgets (PDB)
```bash
# Get PDBs
kubectl get poddisruptionbudgets
kubectl describe pdb user-service-pdb
```

### Namespace Management
```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace dev

# Delete namespace
kubectl delete namespace dev

# Get resources in namespace
kubectl get all -n monitoring
```

### Deployments Management
```bash
# Deploy from manifest
kubectl apply -f k8s-manifests/

# Deploy specific file
kubectl apply -f k8s-manifests/ingress.yaml

# Deploy from directory
kubectl apply -f k8s-manifests/

# Rollout status
kubectl rollout status deployment/user-service

# Rollout history
kubectl rollout history deployment/user-service

# Rollback to previous version
kubectl rollout undo deployment/user-service

# Scale deployment
kubectl scale deployment user-service --replicas=5

# Delete deployment
kubectl delete deployment user-service
```

### Resource Monitoring
```bash
# Get node resource usage
kubectl top nodes

# Get pod resource usage
kubectl top pods
kubectl top pods -n monitoring

# Get resource metrics
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Secrets & ConfigMaps
```bash
# Get secrets
kubectl get secrets
kubectl get secrets -n monitoring

# Create secret
kubectl create secret generic db-password --from-literal=password=mypass

# View secret (base64 encoded)
kubectl get secret db-password -o jsonpath='{.data.password}'

# Decode secret
kubectl get secret db-password -o jsonpath='{.data.password}' | base64 --decode
```

### Port Forwarding
```bash
# Port forward to service
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Port forward to pod
kubectl port-forward <pod-name> 8080:8080

# Port forward in background
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
```

---

## AWS CLI Commands

### VPC & Networking
```bash
# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[0].Value]' --output table

# List subnets
aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' --output table

# List security groups
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]' --output table

# List NAT Gateways
aws ec2 describe-nat-gateways --query 'NatGateways[*].[NatGatewayId,State,PublicIpAddress]' --output table
```

### EKS Cluster
```bash
# Describe cluster
aws eks describe-cluster --name enterprise-eks-prod

# Get cluster status
aws eks describe-cluster --name enterprise-eks-prod --query 'cluster.status'

# List node groups
aws eks list-nodegroups --cluster-name enterprise-eks-prod

# Describe node group
aws eks describe-nodegroup --cluster-name enterprise-eks-prod --nodegroup-name general

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name enterprise-eks-prod

# List cluster add-ons
aws eks describe-addon --cluster-name enterprise-eks-prod --addon-name aws-ebs-csi-driver
```

### RDS Database
```bash
# List RDS instances
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine]' --output table

# Get database details
aws rds describe-db-instances --db-instance-identifier enterprise-db-prod

# List snapshots
aws rds describe-db-snapshots --db-instance-identifier enterprise-db-prod

# Create snapshot
aws rds create-db-snapshot --db-instance-identifier enterprise-db-prod --db-snapshot-identifier manual-backup-$(date +%Y%m%d)

# Create database backup
pg_dump -h <endpoint> -U dbadmin -d appdb > backup.sql

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier restored-db --db-snapshot-identifier <snapshot-id>
```

### S3 & Logs
```bash
# List S3 buckets
aws s3 ls

# List bucket contents
aws s3 ls s3://enterprise-central-logs-<account>/

# Download logs
aws s3 sync s3://enterprise-central-logs-<account>/ ./logs/

# Check bucket encryption
aws s3api get-bucket-encryption --bucket enterprise-central-logs-<account>/

# Enable versioning
aws s3api put-bucket-versioning --bucket enterprise-tfstate-<account>-us-east-1 --versioning-configuration Status=Enabled
```

### CloudTrail
```bash
# List trails
aws cloudtrail describe-trails

# Get trail status
aws cloudtrail get-trail-status --name enterprise-cloudtrail-prod

# Look up events
aws cloudtrail lookup-events --max-results 10

# Look up specific event
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=CreateCluster
```

### GuardDuty
```bash
# List detectors
aws guardduty list-detectors

# List findings
aws guardduty list-findings --detector-id <detector-id>

# Get findings
aws guardduty get-findings --detector-id <detector-id> --finding-ids <finding-id>

# Create sample findings
aws guardduty create-sample-findings --detector-id <detector-id> --finding-types Trojan.EC2/Coinminer
```

### SecurityHub
```bash
# Check if enabled
aws securityhub describe-hub

# Get compliance summary
aws securityhub get-compliance-summary

# List standards
aws securityhub describe-standards --query 'Standards[*].[Name,StandardsArn]'

# Get findings
aws securityhub get-findings --filters '{"ResourceType": [{"Value": "AwsEc2Instance", "Comparison": "EQUALS"}]}'
```

### KMS
```bash
# List keys
aws kms list-keys

# Describe key
aws kms describe-key --key-id alias/enterprise-prod

# Get key rotation status
aws kms get-key-rotation-status --key-id alias/enterprise-prod

# Enable key rotation
aws kms enable-key-rotation --key-id alias/enterprise-prod
```

---

## Troubleshooting

### EKS Issues
```bash
# Check cluster logs
aws eks describe-cluster --name enterprise-eks-prod \
  --query 'cluster.logging.clusterLogging[*].[types,enabled]'

# Check node readiness
kubectl get nodes -o wide

# Describe problematic node
kubectl describe node <node-name> | tail -50

# Check system pods
kubectl get pods -n kube-system

# Check add-on status
aws eks describe-addon --cluster-name enterprise-eks-prod \
  --addon-name aws-ebs-csi-driver --query 'addon.{status:addonVersion,state:createdAt}'
```

### Pod Issues
```bash
# Get pod events
kubectl describe pod <pod-name> | tail -20

# Check pod logs
kubectl logs <pod-name> --all-containers=true --previous

# Get pod YAML
kubectl get pod <pod-name> -o yaml

# Check resource quotas
kubectl describe resourcequota

# Check which node pod is on
kubectl get pod <pod-name> -o wide
```

### Database Issues
```bash
# Check database status
aws rds describe-db-instances --db-instance-identifier enterprise-db-prod \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Engine:Engine,Endpoint:Endpoint.Address}'

# Check security group rules
aws ec2 describe-security-group-rules --filters Name=group-id,Values=<sg-id>

# Test connection from pod
kubectl run pg-test --image=postgres:15 --rm -it -- \
  psql -h <endpoint> -U dbadmin -d appdb -c "SELECT 1"

# Check RDS logs
aws rds describe-db-log-files --db-instance-identifier enterprise-db-prod

# Get log entries
aws rds download-db-log-file-portion \
  --db-instance-identifier enterprise-db-prod \
  --log-file-name postgresql.log \
  --starting-token 0
```

### Network Issues
```bash
# Check VPC Flow Logs
aws ec2 describe-flow-logs --filter Name=resource-id,Values=<vpc-id>

# Test ALB health
aws elbv2 describe-target-health --target-group-arn <arn>

# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id> | jq '.SecurityGroups[0].IpPermissions'

# Test from pod
kubectl run -it --rm network-test --image=nicolaka/netshoot --restart=Never -- bash
# Inside container:
# curl <service-name>
# netstat -an
# nslookup <service-name>
```

### Monitoring Issues
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring prometheus-0 9090:9090
# Visit http://localhost:9090/targets

# Check Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Get Grafana password
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode

# Check CloudWatch Logs
aws logs describe-log-groups --query 'logGroups[*].[logGroupName,retentionInDays]'

# Get latest log entries
aws logs tail /aws/eks/enterprise-eks-prod --follow
```

---

## Useful Aliases

Add to ~/.bashrc or ~/.zshrc:

```bash
# Terraform aliases
alias tfl="terraform fmt -recursive"
alias tfi="terraform init"
alias tfv="terraform validate"
alias tfp="terraform plan -out=tfplan"
alias tfa="terraform apply tfplan"
alias tfd="terraform destroy"
alias tfs="terraform state"

# Kubernetes aliases
alias k="kubectl"
alias kg="kubectl get"
alias kgn="kubectl get nodes"
alias kgp="kubectl get pods"
alias kgd="kubectl get deployments"
alias kgs="kubectl get services"
alias kd="kubectl describe"
alias kl="kubectl logs"
alias ke="kubectl exec -it"
alias kaf="kubectl apply -f"
alias kdel="kubectl delete"

# AWS aliases
alias s3ls="aws s3 ls"
alias ec2ls="aws ec2 describe-instances"
alias eksdesc="aws eks describe-cluster --name enterprise-eks-prod"

# Port forwarding
alias gpf="kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &"
```

---

## Useful Tools

### Installation
```bash
# kubectx - Switch between clusters
brew install kubectx

# stern - Multi-pod log viewer
brew install stern

# helm - Package manager for Kubernetes
brew install helm

# eksctl - EKS cluster management
brew install eksctl

# k9s - Kubernetes dashboard
brew install derailed/k9s/k9s

# AWS Session Manager plugin
brew install --cask session-manager-plugin
```

### Examples
```bash
# Use kubectx to switch clusters
kubectx enterprise-eks-prod

# Use stern to view logs from multiple pods
stern user-service -n default --tail 50

# Use k9s for interactive cluster management
k9s

# Use eksctl to manage clusters
eksctl get clusters
```

---

**Last Updated**: 2024
**For detailed help**: See DEPLOYMENT_GUIDE.md, ARCHITECTURE.md, or SECURITY.md
