locals {
  apm_filter = "WHERE appName = '${var.app_name}'"
}

resource "newrelic_one_dashboard" "tech_challenge" {
  name        = "Tech Challenge - Oficina Mecanica (${var.environment})"
  permissions = "public_read_write"

  # ---------------------------------------------------------------------
  # Negócio: volume e tempo de ciclo das ordens de serviço
  # ---------------------------------------------------------------------
  page {
    name = "Ordens de servico"

    widget_billboard {
      title  = "OS abertas hoje"
      row    = 1
      column = 1
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM ServiceOrderEvent WHERE event = 'ServiceOrderOpened' SINCE today"
      }
    }

    widget_line {
      title  = "Volume diario de ordens de servico"
      row    = 1
      column = 4
      width  = 9
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM ServiceOrderEvent WHERE event = 'ServiceOrderOpened' TIMESERIES 1 day SINCE 30 days ago"
      }
    }

    widget_bar {
      title  = "Tempo medio por status em segundos (Diagnostico, Execucao, Finalizacao)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(previousStatusDurationMs) / 1000 FROM ServiceOrderEvent WHERE previousStatus IN ('IN_DIAGNOSIS', 'IN_EXECUTION', 'FINISHED') FACET previousStatus SINCE 7 days ago"
      }
    }

    widget_pie {
      title  = "Transicoes por status de destino"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM ServiceOrderEvent FACET status SINCE 7 days ago"
      }
    }

    widget_table {
      title  = "Ultimas transicoes registradas"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT serviceOrderId, previousStatus, status, previousStatusDurationMs, traceId FROM ServiceOrderEvent SINCE 1 day ago LIMIT 50"
      }
    }
  }

  # ---------------------------------------------------------------------
  # APIs: latência, throughput e disponibilidade
  # ---------------------------------------------------------------------
  page {
    name = "APIs"

    widget_billboard {
      title  = "Latencia media (s)"
      row    = 1
      column = 1
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(duration) FROM Transaction ${local.apm_filter} SINCE 1 hour ago"
      }
    }

    widget_billboard {
      title  = "Taxa de erro (%)"
      row    = 1
      column = 4
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction ${local.apm_filter} SINCE 1 hour ago"
      }
    }

    widget_billboard {
      title  = "Requisicoes por minuto"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT rate(count(*), 1 minute) FROM Transaction ${local.apm_filter} SINCE 1 hour ago"
      }
    }

    widget_line {
      title  = "Latencia por percentil"
      row    = 4
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT percentile(duration, 50, 95, 99) FROM Transaction ${local.apm_filter} TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_table {
      title  = "Endpoints mais lentos"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(duration) AS 'Latencia media', count(*) AS 'Chamadas' FROM Transaction ${local.apm_filter} FACET name SINCE 6 hours ago LIMIT 20"
      }
    }

    widget_line {
      title  = "Healthcheck e uptime"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM Transaction WHERE appName = '${var.app_name}' AND name LIKE '%health%' TIMESERIES SINCE 6 hours ago"
      }
    }
  }

  # ---------------------------------------------------------------------
  # Kubernetes: consumo de recursos e escalabilidade
  # ---------------------------------------------------------------------
  page {
    name = "Kubernetes"

    widget_billboard {
      title  = "Pods em execucao"
      row    = 1
      column = 1
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT uniqueCount(podName) FROM K8sPodSample WHERE clusterName = '${var.cluster_name}' AND status = 'Running' SINCE 10 minutes ago"
      }
    }

    widget_line {
      title  = "CPU por pod (cores)"
      row    = 1
      column = 4
      width  = 9
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(cpuUsedCores) FROM K8sContainerSample WHERE clusterName = '${var.cluster_name}' FACET podName TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Memoria por pod (MB)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(memoryWorkingSetBytes) / 1000000 FROM K8sContainerSample WHERE clusterName = '${var.cluster_name}' FACET podName TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Replicas da API (efeito do HPA)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT latest(podsAvailable) FROM K8sDeploymentSample WHERE clusterName = '${var.cluster_name}' AND deploymentName = 'api' TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_table {
      title  = "Reinicios de container"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT latest(restartCount) FROM K8sContainerSample WHERE clusterName = '${var.cluster_name}' FACET podName, containerName SINCE 1 day ago"
      }
    }
  }

  # ---------------------------------------------------------------------
  # Erros de integração e logs correlacionados
  # ---------------------------------------------------------------------
  page {
    name = "Erros e integracoes"

    widget_billboard {
      title  = "Falhas de integracao (1h)"
      row    = 1
      column = 1
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM IntegrationFailureEvent SINCE 1 hour ago"
      }
    }

    widget_line {
      title  = "Falhas por operacao"
      row    = 1
      column = 4
      width  = 9
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM IntegrationFailureEvent FACET operation TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_table {
      title  = "Detalhe das falhas"
      row    = 4
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM IntegrationFailureEvent FACET operation, errorType, message SINCE 1 day ago LIMIT 50"
      }
    }

    widget_line {
      title  = "Logs de erro da aplicacao"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM Log WHERE level = 'error' TIMESERIES SINCE 6 hours ago"
      }
    }

    widget_table {
      title  = "Logs recentes com correlacao"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT timestamp, level, message, correlationId, trace.id FROM Log WHERE level IN ('error', 'warn') SINCE 1 hour ago LIMIT 50"
      }
    }
  }
}
