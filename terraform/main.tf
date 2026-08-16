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



# Configure Kubernetes Provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}


provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}


module "addons" {
  source = "./modules/addons"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }

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

  cluster_name = "${var.project_name}-eks-${var.environment}"
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

  cluster_name = "${var.project_name}-eks-${var.environment}"

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


data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
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

#data "aws_lb" "ingress" {
#  name = "aws-load-balancer-controller"
#}



resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"

  depends_on = [
    module.eks
  ]
  set {
    name  = "provider.name"
    value = "aws"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.external_dns_irsa_role_arn
  }

  set {
    name  = "domainFilters[0]"
    value = "enterprise.local"
  }

  set {
    name  = "policy"
    value = "sync"
  }
}





data "kubernetes_ingress_v1" "app" {
  depends_on = [
    helm_release.external_dns
  ]

  metadata {
    name      = "app-ingress"
    namespace = "default"
  }
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "app.enterprise.local"
  type    = "A"
  ttl     = 300

  records = [
    data.kubernetes_ingress_v1.app.status[0].load_balancer[0].ingress[0].hostname
  ]

  #alias {
  #  name                   = data.aws_lb.ingress.dns_name
  #  zone_id                = data.aws_lb.ingress.zone_id
  #  evaluate_target_health = true
  #}
}




# Module 3: IAM Roles and Service Accounts (IRSA)
module "resources1" {
  source = "./modules/resources1"

  count = var.deploy_k8s_resources ? 1 : 0

  modulesecuritykms_key_arn= module.security.kms_key_arn

  #depends_on = [module.eks]
}
