#!/usr/bin/env bash
set -euo pipefail

# Inicializa o backend S3 derivando o nome do bucket do ID da conta ativa, e
# cria o bucket se ele ainda nao existir.
#
#   ./scripts/tf-init.sh
#   TF_DIR=terraform/environments/prod ./scripts/tf-init.sh -upgrade
#
# Por que o ID da conta entra no nome: nomes de bucket S3 sao globais entre
# todas as contas da AWS, e 'tech-challenge-terraform-state' ja pertence a
# outra pessoa. O sufixo com o ID garante unicidade sem depender de um sufixo
# aleatorio que alguem precisaria anotar.
#
# Por que nao fica escrito no backend.hcl: cada sessao nova do AWS Academy pode
# ser uma conta nova, com ID diferente. E o Terraform resolve o backend antes de
# avaliar qualquer variavel, porque e o backend que da acesso ao state de onde
# ele monta o grafo de configuracao. Logo 'bucket = var.algo' nao existe, e a
# unica forma de nao depender de edicao manual e passar por -backend-config.

TF_DIR="${TF_DIR:-terraform/environments/prod}"
PREFIX="${STATE_BUCKET_PREFIX:-tech-challenge-terraform-state}"
REGION="${AWS_REGION:-us-east-1}"

command -v aws >/dev/null || { echo "erro: aws cli nao encontrado" >&2; exit 1; }
[ -f "${TF_DIR}/backend.hcl" ] \
  || { echo "erro: ${TF_DIR}/backend.hcl nao encontrado" >&2; exit 1; }

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)" \
  || { echo "erro: credenciais da AWS invalidas ou expiradas" >&2; exit 1; }
BUCKET="${PREFIX}-${ACCOUNT}"

if aws s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1; then
  echo "==> bucket de state ${BUCKET} ja existe"
else
  echo "==> criando bucket de state ${BUCKET}"
  # us-east-1 e a unica regiao que rejeita LocationConstraint, por ser a regiao
  # padrao original do S3.
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
  aws s3api put-bucket-versioning --bucket "${BUCKET}" \
    --versioning-configuration Status=Enabled
  echo "==> versionamento habilitado"
fi

# -reconfigure porque em conta nova o bucket muda: nao existe state anterior
# para migrar, o do lab passado morreu junto com a conta.
echo "==> terraform init em ${TF_DIR}"
terraform -chdir="${TF_DIR}" init \
  -input=false \
  -reconfigure \
  -backend-config=backend.hcl \
  -backend-config="bucket=${BUCKET}" \
  "$@"
