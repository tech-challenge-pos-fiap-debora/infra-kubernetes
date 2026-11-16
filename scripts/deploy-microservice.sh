#!/usr/bin/env bash
set -euo pipefail

# Uso: ./scripts/deploy-microservice.sh <name> <job-name> <deployment-name>
# Ex.: ./scripts/deploy-microservice.sh stock stock-migration stock

NAME="${1:?nome do serviço (stock|identity|order|billing)}"
JOB_NAME="${2:?nome do Job}"
DEPLOYMENT_NAME="${3:?nome do Deployment}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="${ROOT}/k8s/overlays/prod-${NAME}"
NAMESPACE="${NAMESPACE:-tech-challenge-namespace}"
TMP="$(mktemp -d)"

cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

kubectl kustomize "${OVERLAY}" > "${TMP}/all.yaml"
csplit -s -f "${TMP}/doc-" "${TMP}/all.yaml" '/^---$/' '{*}' || true

apply_doc() {
  local file="$1"
  if [ -s "${file}" ] && grep -q '^kind:' "${file}"; then
    kubectl apply -f "${file}"
  fi
}

doc_kind() {
  grep '^kind:' "$1" | head -1 | awk '{print $2}'
}

for file in "${TMP}"/doc-*; do
  [ -f "${file}" ] || continue
  kind="$(doc_kind "${file}")"
  case "${kind}" in
    Job|Deployment|HorizontalPodAutoscaler|Ingress) ;;
    *) apply_doc "${file}" ;;
  esac
done

kubectl delete job "${JOB_NAME}" -n "${NAMESPACE}" --ignore-not-found

for file in "${TMP}"/doc-*; do
  [ -f "${file}" ] || continue
  if [ "$(doc_kind "${file}")" = "Job" ]; then
    apply_doc "${file}"
  fi
done

deadline=$((SECONDS + 300))
completed=0
while (( SECONDS < deadline )); do
  if kubectl wait --for=condition=complete "job/${JOB_NAME}" -n "${NAMESPACE}" --timeout=10s; then
    completed=1
    break
  fi
  reasons="$(kubectl get pods -n "${NAMESPACE}" -l "job-name=${JOB_NAME}"     -o jsonpath='{range .items[*].status.containerStatuses[*].state.waiting}{.reason}{"\n"}{end}' 2>/dev/null || true)"
  if echo "${reasons}" | grep -qE 'ErrImagePull|ImagePullBackOff|InvalidImageName'; then
    echo "Falha ao puxar a imagem do Job ${JOB_NAME}." >&2
    kubectl describe pods -n "${NAMESPACE}" -l "job-name=${JOB_NAME}" || true
    exit 1
  fi
done

if [ "${completed}" -ne 1 ]; then
  kubectl logs "job/${JOB_NAME}" -n "${NAMESPACE}" --all-containers || true
  kubectl describe "job/${JOB_NAME}" -n "${NAMESPACE}" || true
  exit 1
fi

for file in "${TMP}"/doc-*; do
  [ -f "${file}" ] || continue
  kind="$(doc_kind "${file}")"
  if [ "${kind}" = "Deployment" ] || [ "${kind}" = "HorizontalPodAutoscaler" ] || [ "${kind}" = "Ingress" ]; then
    apply_doc "${file}"
  fi
done

kubectl rollout status "deployment/${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout=300s
