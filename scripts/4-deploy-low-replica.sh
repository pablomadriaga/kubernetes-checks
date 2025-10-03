#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

# Hacer la solicitud a la API para obtener los deployments de todos los namespaces
RESPONSE=$(curl -k -s -X GET "$CLUSTER_URL/apis/apps/v1/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Verificar si curl tuvo éxito
if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
  echo "  Error: Falló la solicitud a la API de deployments."
  exit 1
fi

printf "\e[32m===Deployments que tienen menos de 2 réplicas===\e[0m\n"

# Contar deployments con menos de 2 réplicas
LOW_REPLICA_COUNT=$(echo "$RESPONSE" | jq '[.items[] | select(.spec.replicas < 2)] | length')

# Comprobar si jq tuvo éxito
if [ $? -ne 0 ]; then
  echo "  Error: Hubo un problema al procesar la salida con jq."
  exit 1
fi

# Mostrar el resultado con ✔ o ✖
if [ "$LOW_REPLICA_COUNT" -eq 0 ]; then
  printf "  \e[38;5;34m✔ Todos los deployments tienen al menos 2 réplicas - OK\e[0m\n"
else
  printf "  \e[31m✖ Deployments con menos de 2 réplicas: $LOW_REPLICA_COUNT\e[0m\n"
  exit 1
fi


