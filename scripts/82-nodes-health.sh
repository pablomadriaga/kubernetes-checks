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


CLUSTER_URL="https://$IP:6443"
UMBRAL=2

check_node_health() {
  log_zone "Analizando problemas de estado de los nodos o cerca del límite de pods"

  # Obtener lista de nodos
  RESPONSE_NODES=$(api_get "$IP" "$TOKEN" "/api/v1/nodes")

  ERROR_NODES=0

  # Iterar sobre cada nodo usando process substitution
  while read -r NODE; do
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

    # Evaluar problemas
    if [ -n "$CONDITIONS" ] || [ "$CURRENT_PODS" -gt "$LIMIT_PODS" ]; then
      ERROR_NODES=$((ERROR_NODES+1))
      log_error "✖ Nodo: $NODE"
      [ -n "$CONDITIONS" ] && echo "    Condiciones críticas:" && echo "$CONDITIONS" | sed 's/^/      /'
      [ "$CURRENT_PODS" -gt "$LIMIT_PODS" ] && echo "    Pods actuales: $CURRENT_PODS / $MAX_PODS (umbral: $LIMIT_PODS)"
    fi

  done < <(echo "$RESPONSE_NODES" | jq -r '.items[].metadata.name')

  # Mensaje final
  if [ "$ERROR_NODES" -gt 0 ]; then
    log_error "✖ Total de nodos con problemas: $ERROR_NODES"
    exit 1
  else
    log_success "✔ Todos los nodos están OK"
  fi
}

check_node_health
