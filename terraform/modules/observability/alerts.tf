resource "newrelic_alert_policy" "main" {
  name                = "Tech Challenge - Oficina Mecanica (${var.environment})"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

# Requisito explícito do escopo: alertar falhas no processamento de ordens de serviço.
resource "newrelic_nrql_alert_condition" "service_order_failures" {
  account_id                   = var.new_relic_account_id
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "Falhas no processamento de ordens de servico"
  type                         = "static"
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = 120
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT count(*) FROM IntegrationFailureEvent"
  }

  critical {
    operator              = "above"
    threshold             = 2
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "api_latency" {
  account_id                   = var.new_relic_account_id
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "Latencia alta nas APIs"
  type                         = "static"
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = 120
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentile(duration, 95) FROM Transaction WHERE appName = '${var.app_name}'"
  }

  critical {
    operator              = "above"
    threshold             = 2
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "api_error_rate" {
  account_id                   = var.new_relic_account_id
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "Taxa de erro das APIs acima do aceitavel"
  type                         = "static"
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = 120
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '${var.app_name}'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# Perda de sinal indica que a aplicação parou de responder (uptime).
resource "newrelic_nrql_alert_condition" "api_healthcheck" {
  account_id                   = var.new_relic_account_id
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "API sem responder healthcheck"
  type                         = "static"
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = 120
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT count(*) FROM Transaction WHERE appName = '${var.app_name}'"
  }

  critical {
    operator              = "below"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "pod_cpu" {
  account_id                   = var.new_relic_account_id
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "CPU do pod da API proxima do limite"
  type                         = "static"
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = 120
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT average(cpuUsedCores / cpuLimitCores) * 100 FROM K8sContainerSample WHERE clusterName = '${var.cluster_name}' AND containerName = 'api'"
  }

  critical {
    operator              = "above"
    threshold             = 85
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

resource "newrelic_nrql_alert_condition" "pod_memory" {
  account_id                   = var.new_relic_account_id
  policy_id                    = newrelic_alert_policy.main.id
  name                         = "Memoria do pod da API proxima do limite"
  type                         = "static"
  enabled                      = true
  aggregation_method           = "event_flow"
  aggregation_window           = 60
  aggregation_delay            = 120
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT average(memoryWorkingSetBytes / memoryLimitBytes) * 100 FROM K8sContainerSample WHERE clusterName = '${var.cluster_name}' AND containerName = 'api'"
  }

  critical {
    operator              = "above"
    threshold             = 85
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
}

# ---------------------------------------------------------------------------
# Monitor sintético externo: prova de uptime independente do cluster.
# ---------------------------------------------------------------------------
resource "newrelic_synthetics_monitor" "healthcheck" {
  count = var.healthcheck_url == "" ? 0 : 1

  account_id       = var.new_relic_account_id
  name             = "Healthcheck da API (${var.environment})"
  type             = "SIMPLE"
  uri              = var.healthcheck_url
  period           = "EVERY_5_MINUTES"
  status           = "ENABLED"
  locations_public = ["AWS_US_EAST_1"]

  treat_redirect_as_failure = true
  verify_ssl                = false
  bypass_head_request       = true
  validation_string         = "ok"
}

# ---------------------------------------------------------------------------
# Notificação por e-mail das políticas acima.
# ---------------------------------------------------------------------------
resource "newrelic_notification_destination" "email" {
  count = var.alert_email == "" ? 0 : 1

  account_id = var.new_relic_account_id
  name       = "email-tech-challenge"
  type       = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  count = var.alert_email == "" ? 0 : 1

  account_id     = var.new_relic_account_id
  name           = "email-tech-challenge"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email[0].id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[Tech Challenge] {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "email" {
  count = var.alert_email == "" ? 0 : 1

  account_id            = var.new_relic_account_id
  name                  = "Notificacoes Tech Challenge"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "policy-filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.main.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email[0].id
  }
}
