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

if ! kubectl wait --for=condition=complete "job/api-migration" -n "${NAMESPACE}" --timeout=300s; then
  kubectl logs job/api-migration -n "${NAMESPACE}" --all-containers || true
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
