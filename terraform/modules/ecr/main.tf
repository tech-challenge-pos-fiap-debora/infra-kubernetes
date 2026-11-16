locals {
  name = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
  repositories = [
    "tech-challenge-api",
    "tech-challenge-api-migrations",
    "billing-service",
    "billing-service-migrations",
    "stock-service",
    "stock-service-migrations",
    "identity-service",
    "identity-service-migrations",
    "order-service",
    "order-service-seed",
  ]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = each.value
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
