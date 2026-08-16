
resource "kubernetes_manifest" "user_service" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    module.eks,
    module.addons,
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "user_service1" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user1.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    module.eks,
    module.addons,
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "user_service2" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user2.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    module.eks,
    module.addons,
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "user_service3" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user3.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    module.eks,
    module.addons,
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "user_service4" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-user4.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    module.eks,
    module.addons,
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "order_service" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    module.eks,
    module.addons,
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "order_service1" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order1.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "order_service2" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order2.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "order_service3" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order3.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    kubernetes_storage_class.ebs_gp3
  ]
}


resource "kubernetes_manifest" "order_service4" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/microservice-order4.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks]

  depends_on = [
    kubernetes_storage_class.ebs_gp3
  ]
}

resource "kubernetes_manifest" "ingress" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/ingress.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks, module.monitoring]

  depends_on = [
    kubernetes_storage_class.ebs_gp3
  ]
}

resource "kubernetes_manifest" "ingress1" {
  #count    = var.deploy_k8s_resources ? 1 : 0
  manifest = yamldecode(file("${path.module}/k8s-manifests/ingress1.yaml"))

  #depends_on = [kubernetes_namespace.default, module.eks, module.monitoring]

  depends_on = [
    kubernetes_storage_class.ebs_gp3
  ]
}



# Storage Class for EBS volumes
resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
  }


  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"

  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    encrypted  = "true"
    kms_key_id = var.modulesecuritykms_key_arn
  }

  depends_on = [module.eks]
}

# Set default storage class
resource "kubernetes_storage_class" "ebs_gp3_default" {
  metadata {
    name = "ebs-gp3-default"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"

  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    encrypted  = "true"
    kms_key_id = var.modulesecuritykms_key_arn
  }

  depends_on = [kubernetes_storage_class.ebs_gp3]
}


