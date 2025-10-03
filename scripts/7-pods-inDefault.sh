#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

printf "\e[32m===Cantidad de pods en el namespace 'default'===\e[0m\n"

# Hacer la solicitud a la API para obtener los pods en el namespace 'default'
response=$(curl -k -s -X GET "$CLUSTER_URL/api/v1/namespaces/default/pods" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Verificar si la solicitud fue exitosa
if [ $? -ne 0 ] || [ -z "$response" ]; then
  echo "  Error: La solicitud a la API falló o no se obtuvo respuesta."
  exit 1
fi

# Contar pods en el namespace 'default'
pods_count=$(echo "$response" | jq '.items | length')

# Verificar si jq procesó la respuesta correctamente
if [ $? -ne 0 ]; then
  echo "  Error: No se pudo procesar la respuesta JSON con jq."
  exit 1
fi

# Mostrar resultados con ✔/✖
if [ "$pods_count" -eq 0 ]; then
  printf "  \e[38;5;34m✔ No hay pods en el namespace 'default' - OK\e[0m\n"
else
  printf "  \e[31m✖ Pods encontrados en 'default': %s\e[0m\n" "$pods_count"
  exit 1
fi

