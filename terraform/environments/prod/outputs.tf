output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "api_ecr_repository_url" {
  value = module.ecr.api_repository_url
}

output "migrations_ecr_repository_url" {
  value = module.ecr.migrations_repository_url
}

output "namespace" {
  value = module.platform.namespace
}

output "api_image_tag" {
  value = var.api_image_tag
}

output "newrelic_dashboard_url" {
  description = "Link do dashboard de observabilidade, vazio quando desabilitada."
  value       = length(module.observability) > 0 ? module.observability[0].dashboard_permalink : ""
}

output "sns_topic_arn" {
  value = module.messaging.sns_topic_arn
}

output "order_queue_url" {
  value = module.messaging.order_queue_url
}

output "stock_queue_url" {
  value = module.messaging.stock_queue_url
}

output "billing_queue_url" {
  value = module.messaging.billing_queue_url
}
