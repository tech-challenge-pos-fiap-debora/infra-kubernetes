terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.43"
    }
  }
}

resource "kubernetes_namespace" "newrelic" {
  metadata {
    name = "newrelic"
    labels = {
      "app.kubernetes.io/part-of" = "tech-challenge-pos-fiap"
    }
  }
}

/*
 * nri-bundle reúne os componentes de coleta do cluster:
 *  - newrelic-infrastructure: CPU, memória e estado de nós e pods
 *  - nri-kube-events: eventos do Kubernetes (OOMKill, falha de agendamento)
 *  - kube-state-metrics: estado dos objetos (deployments, HPA, réplicas)
 *  - nri-metadata-injection: liga cada transação do APM ao pod de origem
 *  - newrelic-logging fica desligado: logs da API já vão pelo agente Node
 */
resource "helm_release" "nri_bundle" {
  name       = "newrelic-bundle"
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  version    = var.nri_bundle_version
  namespace  = kubernetes_namespace.newrelic.metadata[0].name

  # O cluster do Learner Lab é pequeno; a instalação completa demora.
  timeout = 900

  values = [
    yamlencode({
      global = {
        licenseKey = var.new_relic_license_key
        cluster    = var.cluster_name
        # Descarta atributos de alta cardinalidade para caber no free tier.
        lowDataMode = true
      }

      newrelic-infrastructure = {
        privileged = true
      }

      kube-state-metrics = {
        enabled = true
      }

      nri-kube-events = {
        enabled = true
      }

      # Desligado de propósito: o agente Node já encaminha os logs da API
      # (application_logging.forwarding) e a Lambda usa a extensão oficial.
      # Ligar o Fluent Bit aqui duplicaria cada linha no New Relic e comeria
      # o free tier sem ganho de correlação.
      newrelic-logging = {
        enabled = false
      }

      nri-metadata-injection = {
        enabled = true
      }

      # Componentes pagos ou desnecessários para o escopo.
      nri-prometheus = {
        enabled = false
      }
      newrelic-prometheus-agent = {
        enabled = false
      }
      newrelic-pixie = {
        enabled = false
      }
      pixie-chart = {
        enabled = false
      }
      newrelic-infra-operator = {
        enabled = false
      }
    })
  ]
}
