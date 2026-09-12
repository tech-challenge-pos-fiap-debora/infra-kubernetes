resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "tech-challenge-pos-fiap"
    }
  }
}

resource "kubernetes_secret" "api" {
  metadata {
    name      = "api-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "api"
      "app.kubernetes.io/part-of" = "tech-challenge-pos-fiap"
    }
  }

  data = {
    MONGO_URL           = var.mongo_url
    JWT_SECRET          = var.jwt_secret
    SEED_ADMIN_PASSWORD = var.seed_admin_password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.app]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.2"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}
