#!/bin/bash

CLUSTER_NAME=$1
TOKEN=$2
CERTIFICATE=$3
IP=$4
CLUSTER_URL="https://$IP:6443"

# Definir los namespaces a excluir
EXCLUDED_NAMESPACES=("kube-system" "tanzu-system" "tanzu-system-ingress" "tanzu-system-monitoring" \
"vmware-system-auth" "vmware-system-cloud-provider" "vmware-system-csi" "vmware-system-tmc" \
"vmware-system-tsm" "tkg-system" "cert-manager" "gatekeeper-system" \
"tanzu-observability-saas" "tanzu-package-repo-global")

printf "\e[32m===Cantidad de contenedores sin Requests y Limits===\e[0m\n"

# Convertir el array de namespaces a formato JSON para jq
EXCLUDED_JSON=$(echo "${EXCLUDED_NAMESPACES[@]}" | jq -R -s 'split(" ")')

# Obtener todos los deployments
RESPONSE=$(curl -k -s -X GET "$CLUSTER_URL/apis/apps/v1/deployments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

# Verificar si la solicitud fue exitosa
if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
  echo "  Error: Falló la solicitud a la API de deployments."
  exit 1
fi

# Contar contenedores sin requests/limits
NO_REQ_CPU=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.resources.requests.cpu == null)
  ] | length')

NO_REQ_MEM=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.resources.requests.memory == null)
  ] | length')

NO_LIMIT_CPU=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.resources.limits.cpu == null)
  ] | length')

NO_LIMIT_MEM=$(echo "$RESPONSE" | jq --argjson excludedNamespaces "$EXCLUDED_JSON" '
  [.items[] | select(.metadata.namespace | IN($excludedNamespaces[]) | not)
   | .spec.template.spec.containers[]
   | select(.resources.limits.memory == null)
  ] | length')

# Mostrar resultados separados por línea
if [ "$NO_REQ_CPU" -eq 0 ]; then
  printf "  \e[38;5;34m✔ Todos los contenedores tienen Requests CPU - OK\e[0m\n"
else
  printf "  \e[31m✖ Contenedores sin Requests CPU: %s\e[0m\n" "$NO_REQ_CPU"
fi

if [ "$NO_LIMIT_CPU" -eq 0 ]; then
  printf "  \e[38;5;34m✔ Todos los contenedores tienen Limits CPU - OK\e[0m\n"
else
  printf "  \e[31m✖ Contenedores sin Limits CPU: %s\e[0m\n" "$NO_LIMIT_CPU"
fi

if [ "$NO_REQ_MEM" -eq 0 ]; then
  printf "  \e[38;5;34m✔ Todos los contenedores tienen Requests Memoria - OK\e[0m\n"
else
  printf "  \e[31m✖ Contenedores sin Requests Memoria: %s\e[0m\n" "$NO_REQ_MEM"
fi

if [ "$NO_LIMIT_MEM" -eq 0 ]; then
  printf "  \e[38;5;34m✔ Todos los contenedores tienen Limits Memoria - OK\e[0m\n"
else
  printf "  \e[31m✖ Contenedores sin Limits Memoria: %s\e[0m\n" "$NO_LIMIT_MEM"
fi

# Salir con código 1 si hubo algún contenedor que no cumple
if [ "$NO_REQ_CPU" -gt 0 ] || [ "$NO_REQ_MEM" -gt 0 ] || [ "$NO_LIMIT_CPU" -gt 0 ] || [ "$NO_LIMIT_MEM" -gt 0 ]; then
  exit 1
fi

