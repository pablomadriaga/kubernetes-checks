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

log_zone "Chequeo cantidad de pods en el namespace 'default'"

# Hacer la solicitud a la API para obtener los pods en el namespace 'default'
response=$(api_get "$IP" "$TOKEN" "/api/v1/namespaces/default/pods")

# Verificar si la solicitud fue exitosa
if [ $? -ne 0 ] || [ -z "$response" ]; then
  echo "  Error: La solicitud a la API falló o no se obtuvo respuesta."
  exit 2
fi

# Contar pods en el namespace 'default'
pods_count=$(echo "$response" | jq '.items | length')

# Verificar si jq procesó la respuesta correctamente
if [ $? -ne 0 ]; then
  echo "  Error: No se pudo procesar la respuesta JSON con jq."
  exit 2
fi

# Mostrar resultados con ✔ /✖
if [ "$pods_count" -eq 0 ]; then
  log_success "✔ No hay pods en el namespace 'default' - OK"
else
  log_error "✖ Pods encontrados en 'default': %s" "$pods_count"
fi
