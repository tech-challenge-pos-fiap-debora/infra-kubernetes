output "dashboard_permalink" {
  description = "Link direto para o dashboard criado."
  value       = newrelic_one_dashboard.tech_challenge.permalink
}

output "alert_policy_id" {
  description = "Id da política que agrupa as condições de alerta."
  value       = newrelic_alert_policy.main.id
}

output "newrelic_namespace" {
  description = "Namespace onde os agentes de coleta foram instalados."
  value       = kubernetes_namespace.newrelic.metadata[0].name
}
