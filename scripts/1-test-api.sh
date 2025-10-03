#!/bin/bash 

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

# Imprimir mensaje de prueba
printf "\e[32m===Test de conexión a la API===\e[0m\n"

# Hacer la solicitud GET para obtener el estado del clúster
response=$(curl -k -s -X GET "$CLUSTER_URL/healthz" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")

# Verificar el estado de la respuesta
if [[ "$response" == "ok" ]]; then
  printf "\e[38;5;34m===API cluster: $CLUSTER_NAME está OK===\e[0m\n"
  exit 0
else
  printf "\e[38;5;160m===API cluster: $CLUSTER_NAME no está OK. Estado: $response===\e[0m\n"
  continue 2
  exit 1
fi

