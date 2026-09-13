variable "project_name" {
  type    = string
  default = "tech-challenge"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "cluster_name" {
  description = "Nome do cluster EKS, usado para agrupar a telemetria no New Relic."
  type        = string
}

variable "new_relic_account_id" {
  description = "Account ID do New Relic."
  type        = number
}

variable "new_relic_license_key" {
  description = "Chave de ingestão (INGEST - LICENSE) usada pelos agentes."
  type        = string
  sensitive   = true
}

variable "app_name" {
  description = "Nome da aplicação no APM, precisa casar com NEW_RELIC_APP_NAME da API."
  type        = string
  default     = "tech-challenge-api"
}

variable "lambda_app_name" {
  description = "Nome da função de autenticação no New Relic."
  type        = string
  default     = "tech-challenge-lambda-auth"
}

variable "alert_email" {
  description = "Destino das notificações de alerta. Vazio desabilita o envio."
  type        = string
  default     = ""
}

variable "healthcheck_url" {
  description = "URL pública do healthcheck monitorada pelo synthetic. Vazio desabilita o monitor."
  type        = string
  default     = ""
}

variable "nri_bundle_version" {
  description = "Versão do chart nri-bundle."
  type        = string
  default     = "5.0.101"
}
