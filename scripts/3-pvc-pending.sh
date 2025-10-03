#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

check_pvc_status() {
  printf "\e[32m===Analizando PVs y PVCs no Bound===\e[0m\n"

  # Analizar PVs
  RESPONSE_PV=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/persistentvolumes" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

  if [ $? -ne 0 ] || [ -z "$RESPONSE_PV" ]; then
    echo "  Error: Falló la solicitud a la API de PVs."
    exit 1
  fi

  PVs_NOT_BOUND=$(echo "$RESPONSE_PV" | jq '[.items[] | select(.status.phase != "Bound")] | length')

  if [ "$PVs_NOT_BOUND" -eq 0 ]; then
    printf "  \e[38;5;34m✔ Todos los PVs están en estado Bound - OK\e[0m\n"
  else
    printf "  \e[31m✖ PVs no Bound: %s\e[0m\n" "$PVs_NOT_BOUND"
  fi

  # Analizar PVCs
  RESPONSE_PVC=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/persistentvolumeclaims" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

  if [ $? -ne 0 ] || [ -z "$RESPONSE_PVC" ]; then
    echo "  Error: Falló la solicitud a la API de PVCs."
    exit 1
  fi

  PVCs_NOT_BOUND=$(echo "$RESPONSE_PVC" | jq '[.items[] | select(.status.phase != "Bound")] | length')

  if [ "$PVCs_NOT_BOUND" -eq 0 ]; then
    printf "  \e[38;5;34m✔ Todos los PVCs están en estado Bound - OK\e[0m\n"
  else
    printf "  \e[31m✖ PVCs no Bound: %s\e[0m\n" "$PVCs_NOT_BOUND"
  fi

  # Salir con código 1 si hay PVs o PVCs no Bound
  if [ "$PVs_NOT_BOUND" -gt 0 ] || [ "$PVCs_NOT_BOUND" -gt 0 ]; then
    exit 1
  fi
}

check_pvc_status

