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

variable "billing_database_url" {
  description = "DATABASE_URL do billing-service (RDS, database billing). Vazio pula o secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "stock_database_url" {
  description = "DATABASE_URL do stock-service (RDS, database stock). Vazio pula o secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "identity_database_url" {
  description = "DATABASE_URL do identity-service (RDS, database identity). Vazio pula o secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "order_mongodb_uri" {
  description = "MONGODB_URI do order-service. Vazio usa mongodb://order-mongo:27017/order."
  type        = string
  sensitive   = true
  default     = ""
}

variable "sns_topic_arn" {
  description = "ARN do tópico SNS de eventos de domínio."
  type        = string
  default     = ""
}

variable "order_queue_url" {
  type    = string
  default = ""
}

variable "stock_queue_url" {
  type    = string
  default = ""
}

variable "billing_queue_url" {
  type    = string
  default = ""
}
