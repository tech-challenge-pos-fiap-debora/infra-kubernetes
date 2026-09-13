#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="${ROOT}/k8s/overlays/prod"
NAMESPACE="${NAMESPACE:-tech-challenge-namespace}"
TMP="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP}"
}
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

kubectl delete job api-migration -n "${NAMESPACE}" --ignore-not-found

for file in "${TMP}"/doc-*; do
  [ -f "${file}" ] || continue
  if [ "$(doc_kind "${file}")" = "Job" ]; then
    apply_doc "${file}"
  fi
done

deadline=$((SECONDS + 300))
completed=0
while (( SECONDS < deadline )); do
  if kubectl wait --for=condition=complete "job/api-migration" -n "${NAMESPACE}" --timeout=10s; then
    completed=1
    break
  fi

  reasons="$(kubectl get pods -n "${NAMESPACE}" -l job-name=api-migration \
    -o jsonpath='{range .items[*].status.containerStatuses[*].state.waiting}{.reason}{"\n"}{end}' 2>/dev/null || true)"
  if echo "${reasons}" | grep -qE 'ErrImagePull|ImagePullBackOff|InvalidImageName'; then
    echo "Falha ao puxar a imagem do Job de migration." >&2
    kubectl describe pods -n "${NAMESPACE}" -l job-name=api-migration || true
    exit 1
  fi
done

if [ "${completed}" -ne 1 ]; then
  kubectl logs job/api-migration -n "${NAMESPACE}" --all-containers || true
  kubectl describe job api-migration -n "${NAMESPACE}" || true
  exit 1
fi

for file in "${TMP}"/doc-*; do
  [ -f "${file}" ] || continue
  kind="$(doc_kind "${file}")"
  if [ "${kind}" = "Deployment" ] || [ "${kind}" = "HorizontalPodAutoscaler" ] || [ "${kind}" = "Ingress" ]; then
    apply_doc "${file}"
  fi
done

kubectl rollout status deployment/api -n "${NAMESPACE}" --timeout=300s
