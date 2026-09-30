#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

if [[ "$#" -lt 5 ]]; then
  printf 'Uso: %s <cluster> <token> <certificate> <ip> <environment>\n' "$0" >&2
  exit 2
fi

readonly CLUSTER_NAME="$1"
readonly TOKEN="$2"
readonly CERTIFICATE="$3"
readonly IP="$4"
readonly ENV="$5"

#LOG_LEVEL=INFO

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/api.sh"

readonly PDBS_PATH="/apis/policy/v1/poddisruptionbudgets"

log_zone "Chequeo de PodDisruptionBudgets"
log_info "Consultando PDBs en el cluster $CLUSTER_NAME"
log_debug "Endpoint consultado: ${PDBS_PATH}"

response=$(api_get "$IP" "$TOKEN" "$PDBS_PATH")
request_status=$?

if [[ "$request_status" -ne 0 || -z "$response" ]]; then
  log_error "✖ Error al consultar PDBs"
  exit 2
fi

if ! jq -e '
  .kind == "PodDisruptionBudgetList" and
  (.items | type == "array") and
  all(.items[];
    (.metadata.namespace | type == "string") and
    (.metadata.name | type == "string") and
    (.status.disruptionsAllowed | type == "number") and
    (.status.expectedPods | type == "number")
  )
' <<<"$response" >/dev/null 2>&1; then
  log_error "✖ Error al consultar PDBs: respuesta inválida de la API"
  exit 2
fi

total_pdbs=$(jq '.items | length' <<<"$response")
log_info "PDBs encontrados: %s" "$total_pdbs"
log_debug "Respuesta validada como PodDisruptionBudgetList"

if [[ "$total_pdbs" -gt 0 ]]; then
  while IFS=$'\t' read -r namespace name disruptions_allowed min_available max_unavailable current_healthy desired_healthy expected_pods selector; do
    log_debug "PDB $namespace/$name: disruptionsAllowed=$disruptions_allowed minAvailable=$min_available maxUnavailable=$max_unavailable currentHealthy=$current_healthy desiredHealthy=$desired_healthy expectedPods=$expected_pods selector=$selector"
  done < <(
    jq -r '
      .items[]
      | [
          .metadata.namespace,
          .metadata.name,
          ((.status.disruptionsAllowed // "-") | tostring),
          ((.spec.minAvailable // "-") | tostring),
          ((.spec.maxUnavailable // "-") | tostring),
          ((.status.currentHealthy // "-") | tostring),
          ((.status.desiredHealthy // "-") | tostring),
          ((.status.expectedPods // "-") | tostring),
          ((.spec.selector // {}) | tojson)
        ]
      | @tsv
    ' <<<"$response"
  )
fi

blocked_pdbs=$(jq '[
  .items[]
  | select(.status.disruptionsAllowed == 0 and .status.expectedPods > 0)
  | {
      namespace: .metadata.namespace,
      name: .metadata.name,
      disruptionsAllowed: .status.disruptionsAllowed
    }
]' <<<"$response")

blocked_count=$(jq 'length' <<<"$blocked_pdbs")
log_debug "PDBs bloqueantes (disruptionsAllowed=0 y expectedPods>0): %s" "$blocked_count"

warning_pdbs=$(jq '[
  .items[]
  | select(.status.disruptionsAllowed == 0 and .status.expectedPods == 0)
  | {
      namespace: .metadata.namespace,
      name: .metadata.name,
      disruptionsAllowed: .status.disruptionsAllowed
    }
]' <<<"$response")

warning_count=$(jq 'length' <<<"$warning_pdbs")
log_debug "PDBs con disruptionsAllowed=0 y expectedPods=0: %s" "$warning_count"

if [[ "$warning_count" -gt 0 ]]; then
  log_warn "PDBs sin pods asociados: %s" "$warning_count"

  while IFS=$'\t' read -r namespace name disruptions_allowed; do
    log_warn "  PDB %s/%s - disruptionsAllowed=%s, expectedPods=0" \
      "$namespace" "$name" "$disruptions_allowed"
  done < <(
    jq -r '.[] | [.namespace, .name, .disruptionsAllowed] | @tsv' <<<"$warning_pdbs"
  )
fi

if [[ "$blocked_count" -eq 0 ]]; then
  if [[ "$total_pdbs" -eq 0 ]]; then
    log_success "✔ No se encontraron PDBs - OK"
  elif [[ "$warning_count" -gt 0 ]]; then
    log_success "✔ No se encontraron PDBs bloqueantes - OK"
  else
    log_success "✔ Todos los PDBs permiten al menos una disrupción - OK"
  fi
  exit 0
fi

log_error "✖ PDBs con disruptionsAllowed=0: %s" "$blocked_count"

while IFS=$'\t' read -r namespace name disruptions_allowed; do
  log_error "  PDB %s/%s - disruptionsAllowed=%s" \
    "$namespace" "$name" "$disruptions_allowed"
done < <(
  jq -r '.[] | [.namespace, .name, .disruptionsAllowed] | @tsv' <<<"$blocked_pdbs"
)

# Los PDB bloqueantes son hallazgos funcionales, no errores técnicos del script.
exit 0
