#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

printf "\e[32m===Test de conexión a la API===\e[0m\n"

response=$(curl -k -s \
  -H "Authorization: Bearer $TOKEN" \
  "$CLUSTER_URL/healthz")

if [[ "$response" == "ok" ]]; then
  printf "\e[38;5;34m===API cluster: %s está OK===\e[0m\n" "$CLUSTER_NAME"
  exit 0
else
  printf "\e[38;5;160m===API cluster: %s no está OK. Estado: %s===\e[0m\n" \
    "$CLUSTER_NAME" "$response"
  exit 1
fi
