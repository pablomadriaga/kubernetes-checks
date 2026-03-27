#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
ENV=$5

#LOG_LEVEL=INFO

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/api.sh"

log_zone "Chequeo PVs y PVCs no Bound"
check_pvc_status() {

  # Analizar PVs
  RESPONSE_PV=$(api_get "$IP" "$TOKEN" "/api/v1/persistentvolumes")

  if [ $? -ne 0 ] || [ -z "$RESPONSE_PV" ]; then
    log_error "✖ Error: Falló la solicitud a la API de PVs."
    exit 1
  fi

  PVs_NOT_BOUND=$(echo "$RESPONSE_PV" | jq '[.items[] | select(.status.phase != "Bound")] | length')

  if [ "$PVs_NOT_BOUND" -eq 0 ]; then
    log_success "✔ Todos los PVs están en estado Bound - OK"
  else
    log_error "✖ PVs no Bound: %s" "$PVs_NOT_BOUND"
  fi

  # Analizar PVCs
  RESPONSE_PVC=$(api_get "$IP" "$TOKEN" "/api/v1/persistentvolumeclaims")

  if [ $? -ne 0 ] || [ -z "$RESPONSE_PVC" ]; then
    log_error "✖ Error: Falló la solicitud a la API de PVCs."
    exit 1
  fi

  PVCs_NOT_BOUND=$(echo "$RESPONSE_PVC" | jq '[.items[] | select(.status.phase != "Bound")] | length')

  if [ "$PVCs_NOT_BOUND" -eq 0 ]; then
    log_success "✔ Todos los PVCs están en estado Bound - OK"
  else
    log_error "✖ PVCs no Bound: %s" "$PVCs_NOT_BOUND"
  fi

  # Salir con código 1 si hay PVs o PVCs no Bound
  if [ "$PVs_NOT_BOUND" -gt 0 ] || [ "$PVCs_NOT_BOUND" -gt 0 ]; then
    exit 1
  fi
}

check_pvc_status

