#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4

#LOG_LEVEL=INFO

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/api.sh"

log_zone "Chequeoddeployments que tienen menos de 2 réplicas"

# Hacer la solicitud a la API para obtener los deployments de todos los namespaces
RESPONSE=$(api_get "$IP" "$TOKEN" "/apis/apps/v1/deployments")

# Verificar si la solicitud tuvo éxito
if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
  log_error "✖ Error: Falló la solicitud a la API de deployments."
  exit 1
fi

# Contar deployments con menos de 2 réplicas
LOW_REPLICA_COUNT=$(echo "$RESPONSE" | jq '[.items[] | select(.spec.replicas < 2)] | length')

# Comprobar si jq tuvo éxito
if [ $? -ne 0 ]; then
  log_error "✖ Error: Hubo un problema al procesar la salida con jq."
  exit 1
fi

# Mostrar el resultado con ✔ o ✖
if [ "$LOW_REPLICA_COUNT" -eq 0 ]; then
  log_success "✔ Todos los deployments tienen al menos 2 réplicas - OK"
else
  log_error "✖ Deployments con menos de 2 réplicas: $LOW_REPLICA_COUNT"
fi
