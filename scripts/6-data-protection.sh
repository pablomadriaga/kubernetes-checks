#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

#cantidad de dias hacia atras
DAYS_AGO=2
date_limit=$(date -u -d "$DAYS_AGO days ago 00:00:00" +"%Y-%m-%dT%H:%M:%S")

# Verificar si el CRD de Velero existe
velero_crd=$(curl -k -s -X GET "$CLUSTER_URL/apis/apiextensions.k8s.io/v1/customresourcedefinitions/backupstoragelocations.velero.io" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

printf "\e[32m=== Backups o Restores que no están en estado \"Completed\" ===\e[0m\n"

# Comprobar si la respuesta contiene "not found" o si está vacía
if echo "$velero_crd" | grep -q "not found"; then
  printf "\033[1;33m  [WARNING]Velero no está instalado en este cluster. Omitiendo la comprobación de backups y restores.\033[0m %s\n"
  exit 0
else
  echo "  Velero está instalado. Comenzando la comprobación de backups y restores."

  # Backups fallidos/no completados
  backups_failed=$(curl -k -s -X GET "$CLUSTER_URL/apis/velero.io/v1/backups" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    | jq -r --arg date_limit "$date_limit" '
        [.items[]
          | select(.status.phase != "Completed")
          | select((.status.startTimestamp // .metadata.creationTimestamp) >= $date_limit)
        ] | length')

  if [ "$backups_failed" -gt 0 ]; then
    printf "  \e[31m✖ Backups fallidos en los últimos %s días: %s\e[0m\n" "$DAYS_AGO" "$backups_failed"
  else
    printf "  \e[38;5;34m✔ Todos los backups están OK\e[0m\n"
  fi

  # Restores fallidos/no completados
  restores_failed=$(curl -k -s -X GET "$CLUSTER_URL/apis/velero.io/v1/restores" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    | jq -r --arg date_limit "$date_limit" '
        [.items[]
          | select(.status.phase != "Completed")
          | select((.status.startTimestamp // .metadata.creationTimestamp) >= $date_limit)
        ] | length')

  if [ "$restores_failed" -gt 0 ]; then
    printf "  \e[31m✖ Restores fallidos en los últimos %s días: %s\e[0m\n" "$DAYS_AGO" "$restores_failed"
  else
    printf "  \e[38;5;34m✔ Todos los restores están OK\e[0m\n"
  fi
fi
