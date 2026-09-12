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
