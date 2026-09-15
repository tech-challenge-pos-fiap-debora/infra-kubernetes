variable "namespace" {
  type    = string
  default = "tech-challenge-namespace"
}

variable "database_url" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "seed_admin_password" {
  type      = string
  sensitive = true
}

variable "new_relic_license_key" {
  description = "Chave de ingestão do New Relic usada pelo agente APM da API."
  type        = string
  sensitive   = true
  default     = ""
}
