# Runbook — subir o ambiente em um AWS Academy Learner Lab

Este documento existe porque o Learner Lab descarta credenciais a cada sessão e
zera a conta quando o crédito acaba. Ele descreve como recriar o ambiente do
zero e como reconectar um lab novo a um ambiente que já existe.

Repositórios envolvidos, todos em `github.com/tech-challenge-pos-fiap-debora`:

| Repositório | Papel |
| --- | --- |
| `app` | código da API; publica as imagens no ECR |
| `infra-kubernetes` | VPC, ECR, EKS, workloads, ALB Ingress |
| `lambda-auth` | Lambda de autenticação e API Gateway |
| `infra-database` | RDS PostgreSQL via Terraform |

## Pré-requisitos locais

```bash
brew install awscli terraform kubernetes-cli gh
gh auth login
```

O Terraform precisa ser 1.15.x. Versão diferente da usada nos workflows gera
state incompatível.

## Segredos

Só as três credenciais da AWS rotacionam. As demais são estáveis e ficam em
`~/.tech-challenge-secrets.env`, fora de qualquer repositório, com permissão
`600`. O arquivo é criado na primeira execução do script de sincronização.

| Secret | `app` | `infra-kubernetes` | `lambda-auth` | `infra-database` | Origem |
| --- | :-: | :-: | :-: | :-: | --- |
| `AWS_ACCESS_KEY_ID` | ✔ | ✔ | ✔ | ✔ | painel do lab, rotaciona |
| `AWS_SECRET_ACCESS_KEY` | ✔ | ✔ | ✔ | ✔ | painel do lab, rotaciona |
| `AWS_SESSION_TOKEN` | ✔ | ✔ | ✔ | ✔ | painel do lab, rotaciona |
| `DATABASE_URL` | | ✔ | ✔ | | output `connection_url` do `infra-database` |
| `JWT_SECRET` | | ✔ | ✔ | | gerado; precisa ser idêntico nos dois |
| `SEED_ADMIN_PASSWORD` | | ✔ | | | gerado |
| `INFRA_DISPATCH_TOKEN` | ✔ | | | | PAT clássico, escopos `repo` e `workflow` |

`INFRA_DISPATCH_TOKEN` é opcional: sem ele o pipeline do `app` termina verde e
apenas avisa que o deploy no EKS precisa ser disparado à mão.

### Sincronizar credenciais a cada sessão do lab

No painel do lab, clique em **AWS Details → AWS CLI → Show**, copie o bloco e:

```bash
pbpaste | ~/scripts/pos-fiap-new/sync-lab-credentials.sh
```

O script grava o perfil em `~/.aws/credentials`, valida com
`sts get-caller-identity` e envia as três credenciais para os quatro repositórios,
junto com os segredos estáveis. Use `--local` para atualizar só o perfil local.

## Subir do zero

### 1. RDS PostgreSQL (`infra-database`)

A VPC do `infra-kubernetes` precisa existir **antes** do RDS (subnets privadas
com tag `kubernetes.io/role/internal-elb`). Na primeira vez, suba só a VPC:

```bash
cd infra-kubernetes/terraform/environments/prod
./scripts/tf-init.sh   # ou init manual com backend.hcl
terraform apply -target=module.vpc
```

Depois aplique o banco:

```bash
cd infra-database/terraform/environments/prod
terraform init -input=false -backend-config=backend.hcl
terraform apply
terraform output -raw connection_url
```

Grave a connection string nos secrets (sem abrir editor com a senha visível):

```bash
~/scripts/pos-fiap-new/set-secret.sh DATABASE_URL
~/scripts/pos-fiap-new/sync-lab-credentials.sh < ~/.aws/credentials
```

Instância esperada: `tech-challenge-prod-pg`, PostgreSQL 16, `db.t3.micro`, porta 5432, **sem** acesso público.

### 2. Bucket de state e init

```bash
cd infra-kubernetes
./scripts/tf-init.sh
```

### 3. Infraestrutura Kubernetes

```bash
cd infra-kubernetes/terraform/environments/prod

export TF_VAR_database_url='postgresql://...' TF_VAR_jwt_secret='...' TF_VAR_seed_admin_password='...'

terraform apply -target=module.vpc -target=module.ecr
terraform apply -target=module.eks          # ~15 min
aws eks update-kubeconfig --name tech-challenge-prod-eks --region us-east-1
terraform apply                              # platform + alb_ingress
```

### 4. Imagens da aplicação

O workflow `Publish ECR` do repositório `app` faz o build dos dois targets
(`production` e `migrations`) e publica com a tag do commit. Se o
`INFRA_DISPATCH_TOKEN` estiver configurado, ele dispara o `Deploy Prod` do
`infra-kubernetes` em seguida; caso contrário:

```bash
gh workflow run deploy-prod.yml \
  --repo tech-challenge-pos-fiap-debora/infra-kubernetes \
  -f api_image_tag=<sha>
```

### 5. Lambda de autenticação

Depende da VPC e do RDS. A Lambda roda em subnets privadas e alcança o RDS
pela rede interna (mesmo security group / CIDR da VPC).

```bash
cd lambda-auth
npm ci && npm run build
./scripts/tf-init.sh
terraform -chdir=terraform/environments/prod apply
```

## URLs geradas

```bash
# API no EKS
kubectl get ingress api -n tech-challenge-namespace \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Lambda de autenticação
terraform -chdir=lambda-auth/terraform/environments/prod output -raw api_gateway_url
```

O workflow `Deploy Prod` também publica a URL do ALB no resumo da execução e
valida `/health/live` e `/health/ready` antes de concluir.

## Custo e desligamento

| Recurso | Custo aproximado por dia |
| --- | --- |
| Control plane do EKS | US$ 2,40 |
| NAT Gateway | US$ 1,08 mais tráfego |
| 2 nós `t3.small` | US$ 1,00 |
| ALB | US$ 0,54 |
| RDS `db.t3.micro` | ~US$ 0,50 |

Destrua ao terminar cada sessão, na ordem inversa:

```bash
terraform -chdir=lambda-auth/terraform/environments/prod destroy
terraform -chdir=infra-kubernetes/terraform/environments/prod destroy
terraform -chdir=infra-database/terraform/environments/prod destroy
```

Se o `destroy` da VPC travar, remova o Ingress primeiro:

```bash
kubectl delete ingress api -n tech-challenge-namespace
```

O state no S3 sobrevive ao `destroy` e não gera custo. O RDS gera custo enquanto existir — destrua o `infra-database` quando não for usar.

## Decisões de arquitetura

**Credenciais estáticas no CI em vez de OIDC.** `iam:CreateOpenIDConnectProvider`
é negado. Os workflows usam as três credenciais temporárias como secrets.

**`LabRole` em vez de roles dedicadas.** `iam:CreateRole` é negado. Cluster EKS,
node groups e Lambda compartilham a `LabRole`.

**ALB Controller sem IRSA.** Sem OIDC, o controller usa o instance profile do nó.

**RDS PostgreSQL em vez de DocumentDB.** `CreateDBInstance` é negado para engine
`docdb`. PostgreSQL RDS (`db.t3.micro`, gp2, sem Multi-AZ) funciona no lab.
Justificativa na RFC-002 do repositório `app`.

**Sem Enhanced Monitoring.** Depende de role dedicada, bloqueada no lab.

## Problemas conhecidos

**`BucketAlreadyExists` no init.** Use o sufixo com ID da conta no nome do bucket.

**`AccessDenied` em `s3:PutObject` durante um `apply`.** Sessão do lab encerrada.
Reinicie o lab, sincronize credenciais e recupere `errored.tfstate` se necessário.

**`InvalidClientTokenId`.** Use o script de sincronização; não edite credenciais à mão.

**Lambda/API não alcançam o RDS.** Confirme security group `tech-challenge-prod-rds-sg` (5432 do CIDR `10.0.0.0/16`) e que `DATABASE_URL` aponta para o endpoint privado, não público.

**Ingress sem hostname / ALB não sobe.** Veja o evento do Ingress:

```bash
kubectl describe ingress api -n tech-challenge-namespace
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

| Evento | Causa | Fix |
|--------|-------|-----|
| `NoCredentialProviders` | Pods não alcançam IMDS do nó (hop limit 1) | `terraform apply` com launch template `http_put_response_hop_limit = 2` no módulo EKS |
| `unable to find suitable subnets` | Subnets sem tag de cluster | `terraform apply` com tag `kubernetes.io/cluster/tech-challenge-prod-eks=shared` |

**`kustomize: command not found` no workflow.** O `deploy-prod.yml` já instala o binário standalone.
