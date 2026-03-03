#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

#LOG_LEVEL=INFO

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/api.sh"

#cantidad de dias hacia atras
DAYS_AGO=2
date_limit=$(date -u -d "$DAYS_AGO days ago 00:00:00" +"%Y-%m-%dT%H:%M:%S")

# Verificar si el CRD de Velero existe
velero_crd=$(api_get "$IP" "$TOKEN" "/apis/apiextensions.k8s.io/v1/customresourcedefinitions/backupstoragelocations.velero.io")

log_zone "Chequeo de Dataprotection"

# Comprobar si la respuesta contiene "not found" o si está vacía
if echo "$velero_crd" | grep -q "not found"; then
  log_error "Velero no está instalado en este cluster. Omitiendo la comprobación de backups y restores"
  exit 0
else
  log_info "  Velero está instalado. Comenzando la comprobación de backups y restores."

  # Backups fallidos/no completados
  backups_failed=$(api_get "$IP" "$TOKEN" "/apis/velero.io/v1/backups" \
    | jq -r --arg date_limit "$date_limit" '
        [.items[]
          | select(.status.phase != "Completed")
          | select((.status.startTimestamp // .metadata.creationTimestamp) >= $date_limit)
        ] | length')

  if [ "$backups_failed" -gt 0 ]; then
    log_error "✖ Backups fallidos en los últimos %s días: %s" "$DAYS_AGO" "$backups_failed"
  else
    log_success "✔ Todos los backups están OK"
  fi

  # Restores fallidos/no completados
  restores_failed=$(api_get "$IP" "$TOKEN" "/apis/velero.io/v1/restores" \
    | jq -r --arg date_limit "$date_limit" '
        [.items[]
          | select(.status.phase != "Completed")
          | select((.status.startTimestamp // .metadata.creationTimestamp) >= $date_limit)
        ] | length')

  if [ "$restores_failed" -gt 0 ]; then
    log_error "✖ Restores fallidos en los últimos %s días: %s" "$DAYS_AGO" "$restores_failed"
  else
    log_success "✔ Todos los restores están OK"
  fi
fi

