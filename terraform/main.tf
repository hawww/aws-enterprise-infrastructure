# Data Sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# This will be populated after EKS module is created
#data "aws_eks_cluster" "main" {
#  name = module.eks.cluster_name
#}

# Local variables for tagging
locals {
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      Project     = var.project_name
      Region      = var.aws_region
    }
  )
}


module "addons" {
  source = "./modules/addons"

  cluster_name = module.eks.cluster_name
  aws_region   = var.aws_region

  ebs_csi_role_arn            = module.iam.ebs_csi_role_arn
  alb_controller_role_arn     = module.iam.alb_controller_role_arn
  cluster_autoscaler_role_arn = module.iam.cluster_autoscaler_role_arn
}

# Module 1: Security (KMS, S3, CloudTrail, GuardDuty, SecurityHub)
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  create_securityhub_org_admin = var.create_securityhub_org_admin

  tags = local.common_tags
}

# Module 2: VPC with Multi-AZ design
module "vpc" {
  source = "./modules/vpc"

  project_name    = var.project_name
  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

# Module 3: IAM Roles and Service Accounts (IRSA)
module "iam" {
  source = "./modules/iam"

  cluster_name              = "enterprise-eks-${var.environment}"
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  kms_key_arn               = module.security.kms_key_arn

  tags = local.common_tags

  #depends_on = [module.eks]
}

# Module 4: EKS Cluster with add-ons and Helm providers
module "eks" {
  source = "./modules/eks"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  cluster_version         = var.cluster_version
  vpc_id                  = module.vpc.vpc_id
  private_subnets         = module.vpc.private_subnets
  public_subnets          = module.vpc.public_subnets
  node_instance_types     = var.node_instance_types
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size
  kms_key_arn             = module.security.kms_key_arn
  #ebs_csi_role_arn            = module.iam.ebs_csi_role_arn
  #alb_controller_role_arn     = module.iam.alb_controller_role_arn
  #cluster_autoscaler_role_arn = module.iam.cluster_autoscaler_role_arn

  tags = local.common_tags
}

# Module 5: RDS Multi-AZ Database
module "rds" {
  source = "./modules/rds"
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = "default"
  allowed_security_groups = [
    module.eks.node_security_group_id
  ]
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  backup_retention_days    = var.backup_retention_days
  dr_region                = var.aws_region_dr
  kms_key_arn              = module.security.kms_key_arn
  sns_topic_arn            = module.monitoring.sns_topic_arn

  tags = local.common_tags

  depends_on = [module.vpc, module.security, module.eks]
}

# Module 6: Monitoring (CloudWatch, Prometheus, Grafana)
module "monitoring" {
  source = "./modules/monitoring"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  cluster_name           = module.eks.cluster_name
  alert_email            = var.alert_email
  grafana_admin_password = var.grafana_admin_password
  kms_key_arn            = module.security.kms_key_arn
  monitoring_role_arn    = module.iam.monitoring_role_arn
  eks_depends_on         = module.eks

  tags = local.common_tags
}

# Deploy Kubernetes manifests for microservices
resource "kubernetes_namespace" "default" {
  metadata {
    name = "default"
  }

  depends_on = [module.eks]
}

resource "kubernetes_manifest" "user_service" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "user_service1" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user1.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "user_service2" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user2.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "user_service3" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user3.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "user_service4" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user4.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "order_service" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "order_service1" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order1.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "order_service2" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order2.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "order_service3" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order3.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}


resource "kubernetes_manifest" "order_service4" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order4.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks]
}

resource "kubernetes_manifest" "ingress" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/ingress.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks, module.monitoring]
}

resource "kubernetes_manifest" "ingress1" {
  manifest = yamldecode(file("${path.module}/k8s-manifests/ingress1.yaml"))

  depends_on = [kubernetes_namespace.default, module.eks, module.monitoring]
}

# Route53 for DNS and Failover
resource "aws_route53_zone" "primary" {
  name = "enterprise.local"

  tags = local.common_tags
}

#resource "aws_route53_health_check" "primary_alb" {
#  type              = "HTTP"
#  ip_address        = "" # Will be set to ALB IP
#  port              = 80
#  resource_path     = "/healthz"
#  failure_threshold = 3
#  request_interval  = 30
#
#  tags = merge(
#    local.common_tags,
#    {
#      Name = "primary-health-check"
#    }
#  )
#}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "app"
  type    = "A"

  alias {
    name                   = aws_route53_zone.primary.name
    zone_id                = aws_route53_zone.primary.zone_id
    evaluate_target_health = true
  }
}
