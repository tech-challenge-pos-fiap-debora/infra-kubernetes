locals {
  name                 = "${var.project_name}-${var.environment}"
  service_account_name = "aws-load-balancer-controller"
}

# O Learner Lab nega iam:CreateRole, iam:CreatePolicy e iam:CreateOpenIDConnectProvider,
# e a trust policy da LabRole nao tem principal Federated. IRSA e impossivel aqui.
# O controller usa as credenciais da LabRole atraves do IMDS do node, que ja tem
# permissao ampla de elasticloadbalancing.
resource "kubernetes_service_account" "alb" {
  metadata {
    name      = local.service_account_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = local.service_account_name
    }
  }
}

resource "helm_release" "alb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.2"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = local.service_account_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [kubernetes_service_account.alb]
}
