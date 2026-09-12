output "api_repository_url" {
  value = aws_ecr_repository.this["tech-challenge-api"].repository_url
}

output "migrations_repository_url" {
  value = aws_ecr_repository.this["tech-challenge-api-migrations"].repository_url
}

output "api_repository_arn" {
  value = aws_ecr_repository.this["tech-challenge-api"].arn
}

output "migrations_repository_arn" {
  value = aws_ecr_repository.this["tech-challenge-api-migrations"].arn
}
