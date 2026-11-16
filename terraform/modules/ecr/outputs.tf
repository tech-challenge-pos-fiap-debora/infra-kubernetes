output "repository_urls" {
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

output "api_repository_url" {
  value = aws_ecr_repository.this["tech-challenge-api"].repository_url
}

output "migrations_repository_url" {
  value = aws_ecr_repository.this["tech-challenge-api-migrations"].repository_url
}

output "billing_repository_url" {
  value = aws_ecr_repository.this["billing-service"].repository_url
}

output "billing_migrations_repository_url" {
  value = aws_ecr_repository.this["billing-service-migrations"].repository_url
}

output "stock_repository_url" {
  value = aws_ecr_repository.this["stock-service"].repository_url
}

output "stock_migrations_repository_url" {
  value = aws_ecr_repository.this["stock-service-migrations"].repository_url
}

output "identity_repository_url" {
  value = aws_ecr_repository.this["identity-service"].repository_url
}

output "identity_migrations_repository_url" {
  value = aws_ecr_repository.this["identity-service-migrations"].repository_url
}

output "order_repository_url" {
  value = aws_ecr_repository.this["order-service"].repository_url
}

output "order_seed_repository_url" {
  value = aws_ecr_repository.this["order-service-seed"].repository_url
}

output "api_repository_arn" {
  value = aws_ecr_repository.this["tech-challenge-api"].arn
}

output "migrations_repository_arn" {
  value = aws_ecr_repository.this["tech-challenge-api-migrations"].arn
}
