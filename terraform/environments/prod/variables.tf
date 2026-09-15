variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "tech-challenge"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "availability_zones" {
  type    = list(string)
  default = []
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "api_image_tag" {
  type    = string
  default = "latest"
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

variable "new_relic_account_id" {
  description = "Account ID do New Relic. Zero desabilita a observabilidade."
  type        = number
  default     = 0
}

variable "new_relic_api_key" {
  description = "User API key (NRAK), usada pelo Terraform para criar dashboards e alertas."
  type        = string
  sensitive   = true
  default     = ""
}

variable "new_relic_license_key" {
  description = "Ingest license key (NRAL), usada pelos agentes para enviar telemetria."
  type        = string
  sensitive   = true
  default     = ""
}

variable "alert_email" {
  description = "E-mail que recebe as notificacoes de alerta."
  type        = string
  default     = ""
}

variable "healthcheck_url" {
  description = "URL publica do healthcheck monitorada pelo synthetic."
  type        = string
  default     = ""
}
