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


readonly CLUSTER_URL="https://$IP:6443"
readonly UMBRAL=2                          # pods de margen del límite por nodo
readonly PORCENTAJE_NODOS=60               # % de nodos que deben estar cerca para marcar error

check_node_health() {
  log_zone "Analizando problemas de estado de los nodos o cerca del límite de pods"

  # Obtener lista de nodos
  RESPONSE_NODES=$(api_get "$IP" "$TOKEN" "/api/v1/nodes")

  # Contadores
  NODES_TOTAL=0
  NODES_NEAR_LIMIT=0
  NODES_CRITICAL=0
  NODES_WITH_ISSUES=""

  # Iterar sobre cada nodo
  while read -r NODE; do
    NODES_TOTAL=$((NODES_TOTAL + 1))

    # Chequear condiciones críticas
    CONDITIONS=$(echo "$RESPONSE_NODES" | jq -r --arg NODE "$NODE" '
      .items[] | select(.metadata.name==$NODE) | .status.conditions[] |
      select(
        (.type=="Ready" and .status!="True")
        or (.type=="MemoryPressure" and .status=="True")
        or (.type=="DiskPressure" and .status=="True")
        or (.type=="PIDPressure" and .status=="True")
      ) | "\(.type): \(.status) (\(.reason // "No reason"))"
    ')

    if [ -n "$CONDITIONS" ]; then
      NODES_CRITICAL=$((NODES_CRITICAL + 1))
    fi

    # Límite de pods
    MAX_PODS=$(echo "$RESPONSE_NODES" | jq -r --arg NODE "$NODE" '
      .items[] | select(.metadata.name==$NODE) | .status.allocatable.pods | tonumber
    ')
    LIMIT_PODS=$((MAX_PODS-UMBRAL))

    # Pods actuales en el nodo
    RESPONSE_PODS=$(api_get "$IP" "$TOKEN" "/api/v1/pods?fieldSelector=spec.nodeName=$NODE,status.phase!=Succeeded,status.phase!=Failed")
    CURRENT_PODS=$(echo "$RESPONSE_PODS" | jq '.items | length')

    # Evaluar cerca del límite
    if [ "$CURRENT_PODS" -gt "$LIMIT_PODS" ]; then
      NODES_NEAR_LIMIT=$((NODES_NEAR_LIMIT + 1))
      NODES_WITH_ISSUES="${NODES_WITH_ISSUES}${NODE}: ${CURRENT_PODS}/${MAX_PODS} pods\n"
    fi

  done < <(echo "$RESPONSE_NODES" | jq -r '.items[].metadata.name')

  # Evaluar resultado
  NODES_THRESHOLD=$((NODES_TOTAL * PORCENTAJE_NODOS / 100))

  if [ "$NODES_CRITICAL" -gt 0 ] || [ "$NODES_NEAR_LIMIT" -ge "$NODES_THRESHOLD" ]; then
    [ "$NODES_CRITICAL" -gt 0 ] && \
      log_error "✖ Chequeo de condiciones críticas: FALLO ($NODES_CRITICAL nodos)"
    [ "$NODES_NEAR_LIMIT" -ge "$NODES_THRESHOLD" ] && \
      log_error "✖ Chequeo de límite de pods: FALLO ($NODES_NEAR_LIMIT/$NODES_TOTAL nodos superan el umbral)" && \
      echo -e "$NODES_WITH_ISSUES" | sed 's/^/    /'
    exit 1
  else
    log_success "✔ Chequeo completado"
  fi
}

check_node_health