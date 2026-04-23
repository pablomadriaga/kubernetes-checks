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

  # Iterar sobre cada nodo usando process substitution
  while read -r NODE; do
    NODES_TOTAL=$((NODES_TOTAL + 1))

    # Condiciones críticas
    CONDITIONS=$(echo "$RESPONSE_NODES" | jq -r --arg NODE "$NODE" '
      .items[] | select(.metadata.name==$NODE) | .status.conditions[] |
      select(
        (.type=="Ready" and .status!="True")
        or (.type=="MemoryPressure" and .status=="True")
        or (.type=="DiskPressure" and .status=="True")
        or (.type=="PIDPressure" and .status=="True")
      ) | "\(.type): \(.status) (\(.reason // "No reason"))"
    ')

    # Límite de pods
    MAX_PODS=$(echo "$RESPONSE_NODES" | jq -r --arg NODE "$NODE" '
      .items[] | select(.metadata.name==$NODE) | .status.allocatable.pods | tonumber
    ')
    LIMIT_PODS=$((MAX_PODS-UMBRAL))

    # Pods actuales en el nodo (solo pods activos, como el scheduler)
    RESPONSE_PODS=$(api_get "$IP" "$TOKEN" "/api/v1/pods?fieldSelector=spec.nodeName=$NODE,status.phase!=Succeeded,status.phase!=Failed")
    CURRENT_PODS=$(echo "$RESPONSE_PODS" | jq '.items | length')

    # Evaluar condición crítica (inmediato)
    if [ -n "$CONDITIONS" ]; then
      NODES_CRITICAL=$((NODES_CRITICAL + 1))
      log_error "✖ Nodo: $NODE - Condiciones críticas"
      echo "$CONDITIONS" | sed 's/^/    /'
    fi

    # Evaluar cerca del límite (acumular para chequeo global)
    if [ "$CURRENT_PODS" -gt "$LIMIT_PODS" ]; then
      NODES_NEAR_LIMIT=$((NODES_NEAR_LIMIT + 1))
      NODES_WITH_ISSUES="${NODES_WITH_ISSUES}${NODE}: ${CURRENT_PODS}/${MAX_PODS} pods\n"
    fi

  done < <(echo "$RESPONSE_NODES" | jq -r '.items[].metadata.name')

  # Evaluar resultado global (solo si no hay críticas previas)
  NODES_THRESHOLD=$((NODES_TOTAL * PORCENTAJE_NODOS / 100))

  if [ "$NODES_CRITICAL" -gt 0 ]; then
    log_error "✖ Total de nodos con condiciones críticas: $NODES_CRITICAL"
    exit 1
  elif [ "$NODES_NEAR_LIMIT" -ge "$NODES_THRESHOLD" ]; then
    log_error "✖ $NODES_NEAR_LIMIT nodos cerca del límite (60%+) de $NODES_TOTAL nodos"
    echo -e "$NODES_WITH_ISSUES" | sed 's/^/    /'
    exit 1
  else
    log_success "✔ Chequeo completado (${NODES_NEAR_LIMIT}/${NODES_TOTAL} nodos cerca del límite, umbral no alcanzado)"
  fi
}

check_node_health
