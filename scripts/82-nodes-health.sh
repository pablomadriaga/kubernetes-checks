#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"
UMBRAL=2

check_node_health() {
  printf "\e[32m=== Analizando problemas de estado de los nodos o cerca del límite de pods ===\e[0m\n"

  # Obtener lista de nodos
  RESPONSE_NODES=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/nodes" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

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

    # Pods actuales en el nodo
    RESPONSE_PODS=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/pods?fieldSelector=spec.nodeName=$NODE" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json")
    CURRENT_PODS=$(echo "$RESPONSE_PODS" | jq '.items | length')

    # Evaluar problemas
    if [ -n "$CONDITIONS" ] || [ "$CURRENT_PODS" -gt "$LIMIT_PODS" ]; then
      ERROR_NODES=$((ERROR_NODES+1))
      printf "  \e[31m✖ Nodo: $NODE\e[0m\n"
      [ -n "$CONDITIONS" ] && echo "    Condiciones críticas:" && echo "$CONDITIONS" | sed 's/^/      /'
      [ "$CURRENT_PODS" -gt "$LIMIT_PODS" ] && echo "    Pods actuales: $CURRENT_PODS / $MAX_PODS (umbral: $LIMIT_PODS)"
    fi

  done < <(echo "$RESPONSE_NODES" | jq -r '.items[].metadata.name')

  # Mensaje final
  if [ "$ERROR_NODES" -gt 0 ]; then
    printf "  \e[31m✖ Total de nodos con problemas: $ERROR_NODES\e[0m\n"
    exit 1
  else
    printf "  \e[38;5;34m✔ Todos los nodos están OK\e[0m\n"
  fi
}

check_node_health

