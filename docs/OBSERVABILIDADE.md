# Observabilidade — New Relic

Documento de referência da stack de monitoramento do Tech Challenge. Cobre o
que foi instrumentado, onde cada peça vive e como validar que está funcionando.

## Por que New Relic

O plano gratuito do Datadog cobre apenas monitoramento de infraestrutura (até 5
hosts, 1 dia de retenção de métricas) e **não inclui APM nem gerenciamento de
logs**, que são exatamente os requisitos centrais desta fase. O acesso completo
depende do trial de 14 dias, que expiraria antes da avaliação.

O New Relic tem free tier perpétuo, sem cartão de crédito, com 100 GB de
ingestão por mês, um usuário full e acesso a APM com distributed tracing,
monitoramento de Kubernetes, logs e serverless. Para o volume deste projeto a
cota é folgada e o ambiente continua disponível depois da entrega.

## Arquitetura

```
                    ┌──────────────────────── New Relic (US) ───────────────────────┐
                    │  APM · Logs · Kubernetes · Serverless · Dashboards · Alertas  │
                    └───────▲──────────────────▲──────────────────▲─────────────────┘
                            │                  │                  │
             agente Node.js │      nri-bundle  │      extensão da │ layer
                  (-r newrelic)      (Helm)    │      Lambda      │
                            │                  │                  │
   ┌────────────────────────┴───────┐  ┌───────┴────────┐  ┌──────┴──────────┐
   │ Deployment api (EKS)           │  │ Cluster EKS    │  │ Lambda auth     │
   │ · transações e traces          │  │ · CPU/memória  │  │ · invocações    │
   │ · logs JSON com correlationId  │  │ · eventos K8s  │  │ · logs JSON     │
   │ · eventos de negócio           │  │                │  │                 │
   └────────────────────────────────┘  └────────────────┘  └─────────────────┘
```

## Componentes e onde estão

| Componente | Repositório | Caminho |
|---|---|---|
| Configuração do agente APM | `app` | `newrelic.js` |
| Porta de telemetria (domínio) | `app` | `src/contexts/shared/domain/ports/telemetry.port.ts` |
| Adaptador New Relic / no-op | `app` | `src/contexts/shared/infrastructure/observability/` |
| Logger JSON e correlation id | `app` | `src/contexts/shared/infrastructure/observability/pino-logger.config.ts` |
| Eventos de negócio | `app` | `src/contexts/ordem-de-servico/infrastructure/observability/telemetry-service-order.repository.ts` |
| Captura de falhas de integração | `app` | `src/contexts/shared/interfaces/http/interceptors/telemetry.interceptor.ts` |
| Agentes do cluster (Helm) | `infra-kubernetes` | `terraform/modules/observability/main.tf` |
| Dashboards como código | `infra-kubernetes` | `terraform/modules/observability/dashboards.tf` |
| Alertas e synthetic | `infra-kubernetes` | `terraform/modules/observability/alerts.tf` |
| Instrumentação da Lambda | `lambda-auth` | `terraform/modules/auth/main.tf` |

## Decisões de implementação

**O agente carrega antes da aplicação.** O `CMD` do container é
`node -r newrelic dist/main.js`. A instrumentação precisa envolver os módulos
`http`, `express` e `pg` antes de eles serem exigidos; carregar o agente
por `import` dentro do `main.ts` chegaria tarde demais.

**Telemetria entra por porta, não por dependência direta.** Os casos de uso e o
domínio não conhecem o New Relic: conversam com `TelemetryPort`. Quando não há
license key configurada, o container de injeção fornece a implementação no-op,
e a aplicação sobe normalmente em desenvolvimento e nos testes.

**Eventos de negócio nascem no domínio.** A entidade `ServiceOrder` acumula
eventos em `transitionTo`, que é o único ponto por onde qualquer mudança de
status passa. Um decorador do repositório drena esses eventos depois da
gravação, então só transições efetivamente persistidas viram métrica. Nenhum
caso de uso precisou ser alterado.

**Logs e traces compartilham identificador.** Cada requisição recebe um
`x-request-id` (reaproveitado se o cliente enviar), devolvido no header da
resposta, gravado em toda linha de log e anexado à transação do APM. Os eventos
de negócio carregam o `traceId`, o que permite sair de um evento no dashboard e
abrir o trace correspondente.

## Requisitos do escopo e onde são atendidos

| Requisito | Como é atendido |
|---|---|
| Latência das APIs | APM, página "APIs" do dashboard (média, p50/p95/p99, endpoints mais lentos) |
| CPU e memória do Kubernetes | `newrelic-infrastructure` + `kube-state-metrics`, página "Kubernetes" |
| Healthchecks e uptime | Alerta de perda de sinal e monitor sintético externo em `/health/live` |
| Alertas de falha em ordens de serviço | Condição NRQL sobre `IntegrationFailureEvent` |
| Logs estruturados JSON com correlação | Pino em JSON com `correlationId`; o agente encaminha e anexa `trace.id` |
| Volume diário de ordens de serviço | `ServiceOrderEvent` com `event = 'ServiceOrderOpened'` |
| Tempo médio por status | `previousStatusDurationMs` por `previousStatus` |
| Erros nas integrações | `IntegrationFailureEvent` por operação e tipo de erro |

## Eventos customizados

`ServiceOrderEvent` — uma ocorrência por transição persistida.

| Atributo | Descrição |
|---|---|
| `event` | `ServiceOrderOpened` ou `ServiceOrderStatusChanged` |
| `serviceOrderId` | Identificador da ordem |
| `status` | Status resultante |
| `previousStatus` | Status anterior (ausente na abertura) |
| `previousStatusDurationMs` | Permanência no status anterior |
| `traceId` | Trace que originou a transição |

`IntegrationFailureEvent` — falhas que não são regra de negócio.

| Atributo | Descrição |
|---|---|
| `operation` | `Controller.metodo` que falhou |
| `errorType` | Classe do erro |
| `message` | Mensagem do erro |

## Consultas principais

```sql
-- Volume diário de ordens de serviço
SELECT count(*) FROM ServiceOrderEvent
WHERE event = 'ServiceOrderOpened' TIMESERIES 1 day SINCE 30 days ago

-- Tempo médio por status, em segundos
SELECT average(previousStatusDurationMs) / 1000 FROM ServiceOrderEvent
WHERE previousStatus IN ('IN_DIAGNOSIS', 'IN_EXECUTION', 'FINISHED')
FACET previousStatus SINCE 7 days ago

-- Latência por percentil
SELECT percentile(duration, 50, 95, 99) FROM Transaction
WHERE appName = 'tech-challenge-api' TIMESERIES

-- Consumo de CPU por pod
SELECT average(cpuUsedCores) FROM K8sContainerSample
WHERE clusterName = 'tech-challenge-prod' FACET podName TIMESERIES

-- Rastrear uma requisição específica de ponta a ponta
SELECT timestamp, level, message FROM Log
WHERE correlationId = '<id devolvido no header x-request-id>'
```

## Alertas configurados

| Alerta | Condição |
|---|---|
| Falhas no processamento de ordens de serviço | Mais de 2 `IntegrationFailureEvent` em 5 minutos |
| Latência alta nas APIs | p95 acima de 2s por 5 minutos (aviso em 1s) |
| Taxa de erro acima do aceitável | Mais de 5% das transações com erro por 5 minutos |
| API sem responder | Nenhuma transação registrada por 5 minutos |
| CPU do pod próxima do limite | Acima de 85% do limite por 5 minutos |
| Memória do pod próxima do limite | Acima de 85% do limite por 5 minutos |

As notificações por e-mail são criadas apenas quando `alert_email` está
preenchido. O monitor sintético só é criado quando `healthcheck_url` aponta
para o ALB publicado.

## Secrets necessários

Nos repositórios `infra-kubernetes` e `lambda-auth`:

| Secret | Onde obter | Uso |
|---|---|---|
| `NEW_RELIC_LICENSE_KEY` | API keys, tipo `INGEST - LICENSE` | Agentes enviam telemetria |
| `NEW_RELIC_ACCOUNT_ID` | Número da conta | Identifica a conta de destino |
| `NEW_RELIC_API_KEY` | API keys, tipo `USER` (prefixo `NRAK`) | Terraform cria dashboards e alertas |
| `ALERT_EMAIL` | E-mail de quem recebe alertas | Notificação (opcional) |

Variável de repositório opcional `HEALTHCHECK_URL`, com a URL pública do ALB,
habilita o monitor sintético. Ela só existe depois do primeiro deploy.

Sem `NEW_RELIC_API_KEY` o módulo de observabilidade não é criado e o cluster
sobe normalmente; sem `NEW_RELIC_LICENSE_KEY` a aplicação usa a telemetria
no-op. Isso mantém o ambiente reprovisionável mesmo sem as chaves.

## Como validar

1. Confirme que os agentes subiram: `kubectl get pods -n newrelic`.
2. Gere tráfego na API e verifique em *APM & Services* se `tech-challenge-api`
   aparece com transações.
3. Abra uma ordem de serviço e consulte
   `SELECT * FROM ServiceOrderEvent SINCE 30 minutes ago`.
4. Copie o `x-request-id` devolvido em qualquer resposta e busque por ele em
   *Logs*; a partir do log, abra o trace correspondente.
5. Verifique o dashboard *Tech Challenge - Oficina Mecanica (prod)*, criado
   pelo Terraform. O link sai no output `newrelic_dashboard_url`.
