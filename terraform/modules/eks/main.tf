# Enhanced EKS Cluster Module with IRSA and Add-ons
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.2.0"

  enable_cluster_creator_admin_permissions = true

  cluster_name    = "${var.project_name}-eks-${var.environment}"
  cluster_version = var.cluster_version

  # Cluster API access configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = var.vpc_id
  subnet_ids = concat(var.private_subnets, var.public_subnets)

  # Enable IRSA
  enable_irsa = true

  # Control Plane Logging
  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 30
  cloudwatch_log_group_kms_key_id        = var.kms_key_arn

  # Encryption
  cluster_encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  # Managed Node Groups with Auto Scaling
  eks_managed_node_groups = {
    general = {
      name         = "${var.project_name}-general-ng"
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      disk_size = 100

      labels = {
        Environment = var.environment
        NodeGroup   = "general"
      }

      taints = []

      tags = {
        "NodeGroup" = "general"

        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }

      # Enable detailed monitoring
      enable_monitoring = true
    }
  }

  # Add-ons Configuration
  cluster_addons = {
    #coredns = {
    #  most_recent = true
    #  configuration_values = jsonencode({
    #    computeType = "ec2"
    #  })
    #}
    #kube-proxy = {
    #  most_recent = true
    #}
    #vpc-cni = {
    #  most_recent = true
    #  configuration_values = jsonencode({
    #    env = {
    #      ENABLE_WINDOWS_IPAM = "true"
    #    }
    #  })
    #}
    #aws-ebs-csi-driver = {
    #  most_recent              = true
    #  service_account_role_arn = var.ebs_csi_role_arn
    #}
  }

  tags = var.tags
}

# Enable Auto Scaling for the EKS cluster
resource "aws_autoscaling_group_tag" "cluster_autoscaler_discovery" {
  for_each = module.eks.eks_managed_node_groups

  autoscaling_group_name = each.value.node_group_autoscaling_group_names[0]

  tag {
    key                 = "k8s.io/cluster-autoscaler/${module.eks.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}

# Install AWS Load Balancer Controller
#resource "helm_release" "aws_load_balancer_controller" {
#  name       = "aws-load-balancer-controller"
#  repository = "https://aws.github.io/eks-charts"
#  chart      = "aws-load-balancer-controller"
#  namespace  = "kube-system"
#
#  set {
#    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#    value = var.alb_controller_role_arn
#  }
#
#  set {
#    name  = "clusterName"
#    value = module.eks.cluster_name
#  }
#
#  depends_on = [module.eks]
#}

# Install Cluster Autoscaler
#resource "helm_release" "cluster_autoscaler" {
#  name       = "cluster-autoscaler"
#  repository = "https://kubernetes.github.io/autoscaler"
#  chart      = "cluster-autoscaler"
#  namespace  = "kube-system"
#
#  set {
#    name  = "awsRegion"
#    value = var.aws_region
#  }
#
#  set {
#    name  = "autoDiscovery.clusterName"
#    value = module.eks.cluster_name
#  }
#
#  set {
#    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#    value = var.cluster_autoscaler_role_arn
#  }
#
#  depends_on = [helm_release.aws_load_balancer_controller]
#}

resource "aws_eks_access_entry" "terraform" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::980825417634:root"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::980825417634:root"

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}