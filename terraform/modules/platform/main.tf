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
    DATABASE_URL          = var.database_url
    JWT_SECRET            = var.jwt_secret
    SEED_ADMIN_PASSWORD   = var.seed_admin_password
    NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.app]
}

<<<<<<< Updated upstream
=======
locals {
  ms_secrets = {
    billing = {
      enabled = var.billing_database_url != ""
      data = {
        DATABASE_URL          = var.billing_database_url
        JWT_SECRET            = var.jwt_secret
        NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
        MP_ACCESS_TOKEN       = ""
        MP_WEBHOOK_SECRET     = ""
        SNS_TOPIC_ARN         = var.sns_topic_arn
        SQS_QUEUE_URL         = var.billing_queue_url
      }
    }
    stock = {
      enabled = var.stock_database_url != ""
      data = {
        DATABASE_URL          = var.stock_database_url
        JWT_SECRET            = var.jwt_secret
        NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
        SNS_TOPIC_ARN         = var.sns_topic_arn
        SQS_QUEUE_URL         = var.stock_queue_url
      }
    }
    identity = {
      enabled = var.identity_database_url != ""
      data = {
        DATABASE_URL          = var.identity_database_url
        JWT_SECRET            = var.jwt_secret
        NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
      }
    }
    order = {
      enabled = true
      data = {
        MONGODB_URI           = var.order_mongodb_uri != "" ? var.order_mongodb_uri : "mongodb://order-mongo:27017/order"
        JWT_SECRET            = var.jwt_secret
        NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
        SNS_TOPIC_ARN         = var.sns_topic_arn
        SQS_QUEUE_URL         = var.order_queue_url
      }
    }
  }
}

resource "kubernetes_secret" "microservice" {
  for_each = {
    for name, cfg in local.ms_secrets : name => cfg if cfg.enabled
  }

  metadata {
    name      = "${each.key}-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = each.key
      "app.kubernetes.io/component" = "${each.key}-service"
      "app.kubernetes.io/part-of"   = "tech-challenge-pos-fiap"
    }
  }

  data = each.value.data
  type = "Opaque"

  depends_on = [kubernetes_namespace.app]
}

>>>>>>> Stashed changes
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
